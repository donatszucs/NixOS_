mod mouse;
mod state;

use hidapi::HidApi;
use mouse::KeychronMonitor;
use state::{StateCache, PERIPHERALS_JSON_PATH};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() >= 3 && args[1] == "--set-mouse" {
        if let Ok(val) = args[2].parse::<u8>() {
            let mut cache = StateCache::new();
            let mut state = cache.get_state().clone();
            state.mouse = Some(val);
            state.mouse_updated = Some(state::current_unix_time());
            let _ = cache.update(state);
            let _ = cache.flush();
            println!("[Peripheral Monitor] Mouse battery set to {}%", val);
            return Ok(());
        }
    }

    println!("==================================================");
    println!(" Starting Keychron M6 Peripheral Monitor (Rust)");
    println!(" State cache destination: {}", PERIPHERALS_JSON_PATH);
    println!("==================================================");

    let running = Arc::new(AtomicBool::new(true));
    let r_sig = running.clone();

    tokio::spawn(async move {
        if let Ok(()) = tokio::signal::ctrl_c().await {
            println!("\n[Daemon] Received shutdown signal (Ctrl+C). Exiting...");
            r_sig.store(false, Ordering::SeqCst);
        }
    });

    let (tx_update, mut rx_update) = mpsc::channel::<Option<u8>>(32);

    // Initial state cache load
    let initial_cached = StateCache::load_persisted();
    let init_mouse = initial_cached.mouse;

    // Spawn Keychron M6 Mouse Passive Listener Worker
    let tx_mouse = tx_update.clone();
    let r_mouse = running.clone();
    tokio::task::spawn_blocking(move || {
        println!("[Mouse Worker] Initializing Keychron M6 passive listener...");
        let mut last_mouse_level = init_mouse;
        let mut last_connected = false;

        while r_mouse.load(Ordering::SeqCst) {
            let api = match HidApi::new() {
                Ok(a) => a,
                Err(e) => {
                    eprintln!("[Mouse Worker] Failed to init HidApi: {e}");
                    std::thread::sleep(Duration::from_secs(5));
                    continue;
                }
            };

            let mut devices = KeychronMonitor::open_devices(&api);
            if devices.is_empty() {
                if last_connected {
                    println!("[Mouse Worker] Keychron Link dongle disconnected.");
                    last_connected = false;
                    let _ = tx_mouse.blocking_send(None);
                }
                std::thread::sleep(Duration::from_secs(3));
                continue;
            }

            if !last_connected {
                println!(
                    "[Mouse Worker] Connected to Keychron Link ({} interface(s) opened).",
                    devices.len()
                );
                last_connected = true;
                if let Some(level) = last_mouse_level.or(init_mouse) {
                    let _ = tx_mouse.blocking_send(Some(level));
                }
            }

            // Passive listening sub-loop (Keychron M6 pushes 0x54 reports on power on/off & percentage drop)
            while r_mouse.load(Ordering::SeqCst) {
                if let Some(level) = KeychronMonitor::read_reports(&mut devices, 100) {
                    if last_mouse_level != Some(level) {
                        last_mouse_level = Some(level);
                        let _ = tx_mouse.blocking_send(Some(level));
                    }
                }
            }
        }
        println!("[Mouse Worker] Stopped.");
    });

    // Drop original sender so channel can close when worker stops
    drop(tx_update);

    // Central Atomic State Cache Coordinator
    let mut cache = StateCache::new();
    let mut current_state = cache.get_state().clone();

    // Flush initial state so /tmp/peripherals.json exists immediately
    if let Err(e) = cache.flush() {
        eprintln!("[State Cache] Initial flush error: {e}");
    } else {
        println!(
            "[State Cache] Initialized state file: {} ({:?})",
            PERIPHERALS_JSON_PATH, current_state
        );
    }

    while let Some(mouse_level) = rx_update.recv().await {
        current_state.mouse = mouse_level;
        if mouse_level.is_some() {
            current_state.mouse_updated = Some(state::current_unix_time());
        }

        match cache.update(current_state.clone()) {
            Ok(true) => {
                let serialized = serde_json::to_string(&current_state).unwrap_or_default();
                println!("[State Cache] Atomically wrote update: {}", serialized);
            }
            Ok(false) => {}
            Err(e) => {
                eprintln!("[State Cache] Failed to write cache: {e}");
            }
        }
    }

    println!("[Daemon] Worker stopped. Goodbye.");
    Ok(())
}
