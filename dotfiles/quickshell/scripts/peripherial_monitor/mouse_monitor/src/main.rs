mod hid;
mod ipc;

use hid::KeychronMonitor;
use hidapi::HidApi;
use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime};
use tokio::sync::{mpsc, oneshot};

const STATE_PATH: &str = "/tmp/mouse_state.json";
const SOCKET_PATH: &str = "/tmp/mouse_monitor.sock";

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

// ── State ──

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
struct MouseState {
    pub battery: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charging: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
struct PersistedCache {
    pub battery: Option<u8>,
    #[serde(default)]
    pub updated: Option<u64>,
    #[serde(default)]
    pub name: Option<String>,
}

fn persist_path() -> Option<PathBuf> {
    let home = std::env::var("HOME").ok()?;
    let dir = PathBuf::from(home).join(".local/state/mouse_monitor");
    let _ = fs::create_dir_all(&dir);
    Some(dir.join("cache.json"))
}

fn load_persisted() -> PersistedCache {
    if let Some(p) = persist_path() {
        if let Ok(f) = File::open(p) {
            if let Ok(c) = serde_json::from_reader(f) {
                return c;
            }
        }
    }
    PersistedCache::default()
}

fn save_persisted(cache: &PersistedCache) {
    if let Some(p) = persist_path() {
        if let Ok(f) = File::create(p) {
            let _ = serde_json::to_writer_pretty(f, cache);
        }
    }
}

fn write_state(state: &MouseState) -> std::io::Result<()> {
    let bytes = serde_json::to_vec_pretty(state)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
    let mut f = fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(STATE_PATH)?;
    f.write_all(&bytes)?;
    f.write_all(b"\n")?;
    f.flush()
}

// ── Main ──

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();

    // CLI: poll subcommand
    if args.len() >= 2 && args[1] == "poll" {
        match ipc::send_command(SOCKET_PATH, "poll").await {
            Ok(resp) => {
                print!("{resp}");
                if resp.starts_with("ERROR") {
                    return Err(resp.trim().to_string().into());
                }
                return Ok(());
            }
            Err(e) => {
                eprintln!("[mouse_monitor] Daemon unavailable ({e}), querying directly...");
                let api = HidApi::new()?;
                let mut monitor = KeychronMonitor::open(&api);
                if let Some(data) = monitor.query_status() {
                    let state = MouseState {
                        battery: Some(data.battery),
                        updated: Some(unix_now()),
                        name: Some(monitor.mouse_name),
                        status: Some(
                            if data.charging { "charging" } else { "connected" }.to_string(),
                        ),
                        charging: Some(data.charging),
                    };
                    write_state(&state)?;
                    println!("OK (battery: {}%)", data.battery);
                    return Ok(());
                }
                return Err("Mouse did not respond".into());
            }
        }
    }

    // Daemon mode
    println!("[mouse_monitor] Starting");
    println!("[mouse_monitor] State: {STATE_PATH}");
    println!("[mouse_monitor] Socket: {SOCKET_PATH}");

    let running = Arc::new(AtomicBool::new(true));
    {
        let r = running.clone();
        tokio::spawn(async move {
            let _ = tokio::signal::ctrl_c().await;
            r.store(false, Ordering::SeqCst);
        });
    }

    let (tx_state, mut rx_state) = mpsc::channel::<MouseState>(32);
    let (tx_poll, rx_poll) = mpsc::channel::<oneshot::Sender<Result<(), String>>>(8);

    // Load initial state
    let persisted = load_persisted();
    let mut current = MouseState {
        battery: persisted.battery,
        updated: persisted.updated,
        name: persisted.name.clone(),
        status: Some("disconnected".to_string()),
        charging: Some(false),
    };
    let _ = write_state(&current);

    // Spawn mouse worker
    spawn_mouse_worker(running.clone(), tx_state.clone(), rx_poll);

    // Spawn IPC server
    {
        let poll_tx = tx_poll.clone();
        tokio::spawn(async move {
            if let Err(e) = ipc::serve_mouse(SOCKET_PATH, poll_tx).await {
                eprintln!("[mouse_monitor] IPC stopped: {e}");
            }
        });
    }

    // State writer loop
    let mut persisted = persisted;
    while let Some(new) = rx_state.recv().await {
        let mut cache_changed = false;

        if let Some(lvl) = new.battery {
            if persisted.battery != Some(lvl) {
                persisted.battery = Some(lvl);
                cache_changed = true;
            }
        }
        if let Some(ref n) = new.name {
            if persisted.name.as_ref() != Some(n) {
                persisted.name = Some(n.clone());
                cache_changed = true;
            }
        }
        // Always update the persisted timestamp when we have a fresh reading
        if new.updated.is_some() && new.updated != persisted.updated {
            persisted.updated = new.updated;
            cache_changed = true;
        }

        if cache_changed {
            save_persisted(&persisted);
        }

        // Fill in persisted fields if not provided
        let mut to_write = new;
        if to_write.name.is_none() {
            to_write.name = persisted.name.clone();
        }
        if to_write.battery.is_none() {
            to_write.battery = persisted.battery;
        }
        if to_write.updated.is_none() {
            to_write.updated = persisted.updated.or(current.updated);
        }

        if to_write != current {
            current = to_write;
            if let Err(e) = write_state(&current) {
                eprintln!("[mouse_monitor] Write error: {e}");
            }
        }
    }

    Ok(())
}

// ── Mouse worker ──

fn spawn_mouse_worker(
    running: Arc<AtomicBool>,
    tx: mpsc::Sender<MouseState>,
    mut rx_poll: mpsc::Receiver<oneshot::Sender<Result<(), String>>>,
) {
    tokio::task::spawn_blocking(move || {
        let mut last_battery: Option<u8> = None;
        let mut last_status = String::new();
        let mut last_active = Instant::now();

        const POLL_INTERVAL: Duration = Duration::from_secs(300);
        const IDLE_TIMEOUT: Duration = Duration::from_secs(300);
        const OFF_TIMEOUT: Duration = Duration::from_secs(900);
        const MAX_CONSECUTIVE_ERRORS: u32 = 3;

        while running.load(Ordering::SeqCst) {
            let api = match HidApi::new() {
                Ok(api) => api,
                Err(e) => {
                    eprintln!("[mouse_monitor] HidApi init failed: {e}");
                    while let Ok(tx) = rx_poll.try_recv() {
                        let _ = tx.send(Err(format!("HidApi error: {e}")));
                    }
                    std::thread::sleep(Duration::from_secs(10));
                    continue;
                }
            };

            let mut monitor = KeychronMonitor::open(&api);
            if !monitor.is_connected() {
                if last_status != "disconnected" {
                    last_status = "disconnected".to_string();
                    last_battery = None;
                    let _ = tx.blocking_send(MouseState {
                        battery: None,
                        updated: None,
                        name: None,
                        status: Some("disconnected".to_string()),
                        charging: Some(false),
                    });
                }
                while let Ok(resp) = rx_poll.try_recv() {
                    let _ = resp.send(Err("Mouse dongle not connected".to_string()));
                }
                std::thread::sleep(Duration::from_secs(5));
                continue;
            }

            let mouse_name = monitor.mouse_name.clone();
            let mut last_query = Instant::now() - POLL_INTERVAL; // force immediate first poll
            let mut consecutive_errors: u32 = 0;

            while running.load(Ordering::SeqCst) {
                let now = Instant::now();

                // Manual poll requests
                if let Ok(respond_to) = rx_poll.try_recv() {
                    last_query = now;
                    if let Some(data) = monitor.query_status() {
                        last_active = now;
                        consecutive_errors = 0;
                        let status = if data.charging { "charging" } else { "connected" };
                        last_battery = Some(data.battery);
                        last_status = status.to_string();
                        // Always send with fresh timestamp on manual poll
                        let _ = tx.blocking_send(MouseState {
                            battery: Some(data.battery),
                            updated: Some(unix_now()),
                            name: Some(mouse_name.clone()),
                            status: Some(status.to_string()),
                            charging: Some(data.charging),
                        });
                        let _ = respond_to.send(Ok(()));
                    } else {
                        let _ = respond_to.send(Err("Mouse did not respond".to_string()));
                    }
                }

                // Periodic battery poll
                if now.duration_since(last_query) >= POLL_INTERVAL {
                    last_query = now;
                    if let Some(data) = monitor.query_status() {
                        last_active = now;
                        consecutive_errors = 0;
                        let status = if data.charging { "charging" } else { "connected" };
                        last_battery = Some(data.battery);
                        last_status = status.to_string();
                        let _ = tx.blocking_send(MouseState {
                            battery: Some(data.battery),
                            updated: Some(unix_now()),
                            name: Some(mouse_name.clone()),
                            status: Some(status.to_string()),
                            charging: Some(data.charging),
                        });
                    } else {
                        let elapsed = now.duration_since(last_active);
                        let new_status = if elapsed >= OFF_TIMEOUT {
                            Some("off")
                        } else if elapsed >= IDLE_TIMEOUT {
                            Some("idle")
                        } else {
                            None // no change
                        };
                        if let Some(s) = new_status {
                            if last_status != s {
                                last_status = s.to_string();
                                let _ = tx.blocking_send(MouseState {
                                    battery: last_battery,
                                    updated: None,
                                    name: Some(mouse_name.clone()),
                                    status: Some(s.to_string()),
                                    charging: Some(false),
                                });
                            }
                        }
                    }
                }

                // Passive HID reports
                match monitor.read_passive_reports(100) {
                    Ok(Some(data)) => {
                        last_active = now;
                        consecutive_errors = 0;
                        let status = if data.charging { "charging" } else { "connected" };
                        if last_battery != Some(data.battery) || last_status != status {
                            last_battery = Some(data.battery);
                            last_status = status.to_string();
                            let _ = tx.blocking_send(MouseState {
                                battery: Some(data.battery),
                                updated: Some(unix_now()),
                                name: Some(mouse_name.clone()),
                                status: Some(status.to_string()),
                                charging: Some(data.charging),
                            });
                        }
                    }
                    Ok(None) => {
                        consecutive_errors = 0;
                        let elapsed = now.duration_since(last_active);
                        if last_status == "connected" && elapsed >= IDLE_TIMEOUT {
                            last_status = "idle".to_string();
                            let _ = tx.blocking_send(MouseState {
                                battery: last_battery,
                                updated: None,
                                name: Some(mouse_name.clone()),
                                status: Some("idle".to_string()),
                                charging: Some(false),
                            });
                        } else if last_status == "idle" && elapsed >= OFF_TIMEOUT {
                            last_status = "off".to_string();
                            let _ = tx.blocking_send(MouseState {
                                battery: last_battery,
                                updated: None,
                                name: Some(mouse_name.clone()),
                                status: Some("off".to_string()),
                                charging: Some(false),
                            });
                        }
                    }
                    Err(()) => {
                        consecutive_errors += 1;
                        if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
                            last_status = "disconnected".to_string();
                            last_battery = None;
                            let _ = tx.blocking_send(MouseState {
                                battery: None,
                                updated: None,
                                name: None,
                                status: Some("disconnected".to_string()),
                                charging: Some(false),
                            });
                            std::thread::sleep(Duration::from_secs(5));
                            break;
                        }
                        std::thread::sleep(Duration::from_millis(500));
                    }
                }
            }
        }
    });
}
