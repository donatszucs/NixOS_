mod ipc;
mod tapo;

use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tapo::{LightAction, TapoController};
use tokio::sync::mpsc;

const STATE_PATH: &str = "/tmp/light_state.json";
const SOCKET_PATH: &str = "/tmp/light_controller.sock";

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

// ── State ──

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LightState {
    pub status: LightStatus,
    pub device_on: bool,
    pub brightness: u8,
    pub hue: u16,
    pub saturation: u8,
    pub updated: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LightStatus {
    Connected,
    Disconnected,
}

impl Default for LightState {
    fn default() -> Self {
        Self {
            status: LightStatus::Disconnected,
            device_on: false,
            brightness: 0,
            hue: 30,
            saturation: 0,
            updated: unix_now(),
        }
    }
}

fn disconnected_state(prev: &LightState) -> LightState {
    LightState {
        status: LightStatus::Disconnected,
        updated: unix_now(),
        ..prev.clone()
    }
}

fn persist_path() -> Option<PathBuf> {
    let home = std::env::var("HOME").ok()?;
    let dir = PathBuf::from(home).join(".local/state/light_controller");
    let _ = fs::create_dir_all(&dir);
    Some(dir.join("state.json"))
}

fn load_state() -> LightState {
    // Try runtime state first
    if let Ok(f) = File::open(STATE_PATH) {
        if let Ok(s) = serde_json::from_reader(f) {
            return s;
        }
    }
    // Then persisted
    if let Some(p) = persist_path() {
        if let Ok(f) = File::open(p) {
            if let Ok(s) = serde_json::from_reader(f) {
                return s;
            }
        }
    }
    LightState::default()
}

fn save_state(state: &LightState) -> std::io::Result<()> {
    let bytes = serde_json::to_vec_pretty(state)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;

    let mut f = fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(STATE_PATH)?;
    f.write_all(&bytes)?;
    f.write_all(b"\n")?;
    f.flush()?;

    // Persist to survive reboots
    if let Some(p) = persist_path() {
        if let Ok(mut pf) = File::create(p) {
            let _ = pf.write_all(&bytes);
            let _ = pf.write_all(b"\n");
        }
    }

    Ok(())
}

// ── Main ──

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();

    // CLI mode: send command to running daemon
    if args.len() >= 2 {
        let command = args[1..].join(" ");
        let response = ipc::send_command(SOCKET_PATH, &command).await?;
        print!("{response}");
        if response.starts_with("ERROR") {
            return Err(response.trim().to_string().into());
        }
        return Ok(());
    }

    // Daemon mode
    println!("[light_controller] Starting");
    println!("[light_controller] State: {STATE_PATH}");
    println!("[light_controller] Socket: {SOCKET_PATH}");

    let running = Arc::new(AtomicBool::new(true));
    {
        let r = running.clone();
        tokio::spawn(async move {
            let _ = tokio::signal::ctrl_c().await;
            r.store(false, Ordering::SeqCst);
        });
    }

    let (tx_cmd, rx_cmd) = mpsc::channel::<ipc::LightCommand>(32);

    // IPC server
    {
        let cmd_tx = tx_cmd.clone();
        tokio::spawn(async move {
            if let Err(e) = ipc::serve_light(SOCKET_PATH, cmd_tx).await {
                eprintln!("[light_controller] IPC stopped: {e}");
            }
        });
    }

    // Run the light worker on the main task
    light_worker(running, rx_cmd).await;

    Ok(())
}

// ── Light worker ──

async fn light_worker(
    running: Arc<AtomicBool>,
    mut commands: mpsc::Receiver<ipc::LightCommand>,
) {
    let mut controller: Option<TapoController> = None;
    let mut current = load_state();
    let mut consecutive_failures: u32 = 0;

    // Write initial state and do immediate first refresh
    let _ = save_state(&current);
    refresh(&mut controller, &mut current, &mut consecutive_failures).await;

    let mut poll = tokio::time::interval(Duration::from_secs(10));
    poll.tick().await; // consume first immediate tick

    while running.load(Ordering::SeqCst) {
        tokio::select! {
            _ = poll.tick() => {
                refresh(&mut controller, &mut current, &mut consecutive_failures).await;
            }
            cmd = commands.recv() => {
                let Some(cmd) = cmd else { break };
                handle_command(cmd, &mut controller, &mut current, &mut consecutive_failures).await;
            }
        }
    }
}

async fn ensure_connected(controller: &mut Option<TapoController>) {
    if controller.is_none() {
        *controller = TapoController::connect_from_env().await.ok();
    }
}

async fn refresh(
    controller: &mut Option<TapoController>,
    current: &mut LightState,
    consecutive_failures: &mut u32,
) {
    ensure_connected(controller).await;

    if let Some(device) = controller.as_mut() {
        match device.read_state().await {
            Ok(state) => {
                *consecutive_failures = 0;
                if *current != state {
                    *current = state;
                    let _ = save_state(current);
                }
            }
            Err(e) => {
                *consecutive_failures += 1;
                eprintln!(
                    "[light_controller] Refresh failed ({consecutive_failures}x): {e}"
                );
                // Drop controller on error so next time we reconnect fresh
                *controller = None;
                // Only declare disconnected after 2 consecutive failures to avoid flapping
                if *consecutive_failures >= 2 {
                    let new = disconnected_state(current);
                    if *current != new {
                        *current = new;
                        let _ = save_state(current);
                    }
                }
            }
        }
    } else {
        *consecutive_failures += 1;
        if *consecutive_failures >= 2 {
            let new = disconnected_state(current);
            if *current != new {
                *current = new;
                let _ = save_state(current);
            }
        }
    }
}

async fn handle_command(
    command: ipc::LightCommand,
    controller: &mut Option<TapoController>,
    current: &mut LightState,
    consecutive_failures: &mut u32,
) {
    let (action, response_tx) = match command {
        ipc::LightCommand::On(tx) => (LightAction::On, tx),
        ipc::LightCommand::Off(tx) => (LightAction::Off, tx),
        ipc::LightCommand::SetBrightness(v, tx) => (LightAction::SetBrightness(v), tx),
        ipc::LightCommand::StepBrightness(delta, tx) => {
            let target = (i16::from(current.brightness) + delta).clamp(1, 100) as u8;
            (LightAction::SetBrightness(target), tx)
        }
        ipc::LightCommand::SetColor(h, s, tx) => (LightAction::SetColor(h, s), tx),
        ipc::LightCommand::White(tx) => (LightAction::White, tx),
        ipc::LightCommand::Refresh(tx) => {
            refresh(controller, current, consecutive_failures).await;
            let _ = tx.send(Ok(()));
            return;
        }
    };

    ensure_connected(controller).await;

    let mut result = if let Some(device) = controller.as_mut() {
        device.execute(action).await
    } else {
        Err("Tapo device unavailable".into())
    };

    // If failed, try reconnecting once and retrying
    if result.is_err() {
        eprintln!("[light_controller] Action failed, reconnecting and retrying...");
        match TapoController::connect_from_env().await {
            Ok(mut new_device) => {
                let retry = new_device.execute(action).await;
                if retry.is_ok() {
                    result = Ok(());
                    *controller = Some(new_device);
                } else {
                    *controller = None;
                }
            }
            Err(_) => {
                *controller = None;
            }
        }
    }

    if let Err(ref e) = result {
        eprintln!("[light_controller] Command failed: {e}");
        let _ = response_tx.send(Err(e.to_string()));
    } else {
        *consecutive_failures = 0;
        // Refresh state after successful command
        refresh(controller, current, consecutive_failures).await;
        let _ = response_tx.send(Ok(()));
    }
}
