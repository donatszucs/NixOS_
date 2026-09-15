mod ipc;
mod mouse;
mod state;
mod tapo;

use hidapi::HidApi;
use ipc::{LightCommand, SOCKET_PATH};
use mouse::KeychronMonitor;
use state::{LightState, StateCache, PERIPHERALS_JSON_PATH};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tapo::{disconnected_state, LightAction, TapoController};
use tokio::sync::{mpsc, oneshot};

#[derive(Debug)]
enum StateUpdate {
    Mouse(Option<u8>),
    Light {
        state: LightState,
        written: Option<oneshot::Sender<Result<(), String>>>,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() >= 2 && args[1] == "light" {
        let command = args[2..].join(" ");
        if command.is_empty() {
            return Err("usage: peripherial_monitor light <on|off|set|color|white>".into());
        }
        let response = ipc::send_command(&command).await?;
        print!("{response}");
        if response.starts_with("ERROR") {
            return Err(response.trim().to_string().into());
        }
        return Ok(());
    }

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

    println!("Starting Keychron M6 Peripheral Monitor (Rust)");
    println!("State cache destination: {}", PERIPHERALS_JSON_PATH);
    println!("Light control socket: {}", SOCKET_PATH);

    let running = Arc::new(AtomicBool::new(true));
    let signal_running = running.clone();
    tokio::spawn(async move {
        if tokio::signal::ctrl_c().await.is_ok() {
            signal_running.store(false, Ordering::SeqCst);
        }
    });

    let (tx_update, mut rx_update) = mpsc::channel::<StateUpdate>(32);
    let (tx_command, rx_command) = mpsc::channel::<LightCommand>(32);

    let mut cache = StateCache::new();
    let current_state = cache.get_state().clone();
    if let Err(error) = cache.flush() {
        eprintln!("[State Cache] Initial flush error: {error}");
    }

    spawn_mouse_worker(running.clone(), tx_update.clone());
    tokio::spawn(light_worker(
        running.clone(),
        rx_command,
        tx_update.clone(),
        current_state.light.clone(),
    ));

    let socket_commands = tx_command.clone();
    tokio::spawn(async move {
        if let Err(error) = ipc::serve(std::path::Path::new(SOCKET_PATH), socket_commands).await {
            eprintln!("[Light IPC] Server stopped: {error}");
        }
    });

    let mut current_state = current_state;

    while let Some(update) = rx_update.recv().await {
        match update {
            StateUpdate::Mouse(mouse_level) => {
                current_state.mouse = mouse_level;
                if mouse_level.is_some() {
                    current_state.mouse_updated = Some(state::current_unix_time());
                }
            }
            StateUpdate::Light { state: light_state, written } => {
                current_state.light = light_state;
                let result = cache
                    .update(current_state.clone())
                    .map(|_| ())
                    .map_err(|error| error.to_string());
                if let Some(written) = written {
                    let _ = written.send(result);
                }
                continue;
            }
        }
        if let Err(error) = cache.update(current_state.clone()) {
            eprintln!("[State Cache] Failed to write cache: {error}");
        }
    }

    Ok(())
}

fn spawn_mouse_worker(running: Arc<AtomicBool>, tx_update: mpsc::Sender<StateUpdate>) {
    tokio::task::spawn_blocking(move || {
        let mut last_mouse_level = None;
        let mut last_connected = false;
        while running.load(Ordering::SeqCst) {
            let api = match HidApi::new() {
                Ok(api) => api,
                Err(error) => {
                    eprintln!("[Mouse Worker] Failed to init HidApi: {error}");
                    std::thread::sleep(Duration::from_secs(5));
                    continue;
                }
            };
            let mut devices = KeychronMonitor::open_devices(&api);
            if devices.is_empty() {
                if last_connected {
                    last_connected = false;
                    let _ = tx_update.blocking_send(StateUpdate::Mouse(None));
                }
                std::thread::sleep(Duration::from_secs(3));
                continue;
            }
            if !last_connected {
                last_connected = true;
                if let Some(level) = last_mouse_level {
                    let _ = tx_update.blocking_send(StateUpdate::Mouse(Some(level)));
                }
            }
            while running.load(Ordering::SeqCst) {
                if let Some(level) = KeychronMonitor::read_reports(&mut devices, 100) {
                    if last_mouse_level != Some(level) {
                        last_mouse_level = Some(level);
                        let _ = tx_update.blocking_send(StateUpdate::Mouse(Some(level)));
                    }
                }
            }
        }
    });
}

async fn light_worker(
    running: Arc<AtomicBool>,
    mut commands: mpsc::Receiver<LightCommand>,
    tx_update: mpsc::Sender<StateUpdate>,
    initial_state: LightState,
) {
    let mut controller = None;
    let mut current = initial_state;
    let mut poll = tokio::time::interval(Duration::from_secs(20));
    poll.tick().await;
    while running.load(Ordering::SeqCst) {
        tokio::select! {
            _ = poll.tick() => refresh_light(&mut controller, &mut current, &tx_update, None).await,
            command = commands.recv() => {
                let Some(command) = command else { break };
                handle_light_command(command, &mut controller, &mut current, &tx_update).await;
            }
        }
    }
}

async fn refresh_light(
    controller: &mut Option<TapoController>,
    current: &mut LightState,
    tx_update: &mpsc::Sender<StateUpdate>,
    written: Option<oneshot::Sender<Result<(), String>>>,
) {
    if controller.is_none() {
        *controller = TapoController::connect_from_env().await.ok();
    }
    if let Some(device) = controller.as_ref() {
        match device.read_state().await {
            Ok(state) => *current = state,
            Err(error) => {
                eprintln!("[Tapo] State refresh failed: {error}");
                *controller = None;
                *current = disconnected_state(current);
            }
        }
    } else {
        *current = disconnected_state(current);
    }
    let _ = tx_update
        .send(StateUpdate::Light {
            state: current.clone(),
            written,
        })
        .await;
}

async fn handle_light_command(
    command: LightCommand,
    controller: &mut Option<TapoController>,
    current: &mut LightState,
    tx_update: &mpsc::Sender<StateUpdate>,
) {
    let (result, response_tx): (Result<(), String>, oneshot::Sender<Result<(), String>>) = match command {
        LightCommand::On(response) => (run_action(controller, LightAction::On).await, response),
        LightCommand::Off(response) => (run_action(controller, LightAction::Off).await, response),
        LightCommand::SetBrightness(value, response) => (run_action(controller, LightAction::SetBrightness(value)).await, response),
        LightCommand::StepBrightness(delta, response) => {
            let current_brightness = i16::from(current.brightness);
            let target = (current_brightness + delta).clamp(1, 100) as u8;
            (run_action(controller, LightAction::SetBrightness(target)).await, response)
        }
        LightCommand::SetColor(hue, saturation, response) => (run_action(controller, LightAction::SetColor(hue, saturation)).await, response),
        LightCommand::White(response) => (run_action(controller, LightAction::White).await, response),
    };

    if let Err(error) = &result {
        *controller = None;
        *current = disconnected_state(current);
        let _ = tx_update
            .send(StateUpdate::Light {
                state: current.clone(),
                written: None,
            })
            .await;
        let _ = response_tx.send(Err(error.clone()));
    } else {
        let (written_tx, written_rx) = oneshot::channel();
        refresh_light(controller, current, tx_update, Some(written_tx)).await;
        let result = written_rx
            .await
            .unwrap_or_else(|_| Err("state writer stopped".to_string()));
        let _ = response_tx.send(result);
    }
}

async fn run_action(controller: &mut Option<TapoController>, action: LightAction) -> Result<(), String> {
    if controller.is_none() {
        *controller = TapoController::connect_from_env().await.ok();
    }
    let Some(device) = controller.as_ref() else {
        return Err("Tapo device is disconnected or credentials are unavailable".to_string());
    };
    device.execute(action).await.map_err(|error| error.to_string())
}
