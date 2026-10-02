use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{mpsc, oneshot};

#[derive(Debug)]
pub enum LightCommand {
    On(oneshot::Sender<Result<(), String>>),
    Off(oneshot::Sender<Result<(), String>>),
    SetBrightness(u8, oneshot::Sender<Result<(), String>>),
    StepBrightness(i16, oneshot::Sender<Result<(), String>>),
    SetColor(u16, u8, oneshot::Sender<Result<(), String>>),
    White(oneshot::Sender<Result<(), String>>),
    Refresh(oneshot::Sender<Result<(), String>>),
}

pub async fn serve_light(
    socket_path: &str,
    command_tx: mpsc::Sender<LightCommand>,
) -> io::Result<()> {
    let path = Path::new(socket_path);
    let _ = std::fs::remove_file(path);
    let listener = UnixListener::bind(path)?;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;

    loop {
        let (stream, _) = listener.accept().await?;
        let tx = command_tx.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, tx).await {
                eprintln!("[light_controller] IPC client error: {e}");
            }
        });
    }
}

async fn handle_client(
    stream: UnixStream,
    command_tx: mpsc::Sender<LightCommand>,
) -> io::Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();

    let Some(line) = lines.next_line().await? else {
        return Ok(());
    };

    let (command, response_rx) = parse_command(line.trim())?;
    command_tx
        .send(command)
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "worker stopped"))?;

    let result = response_rx
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "worker did not respond"))?;

    match result {
        Ok(()) => writer.write_all(b"OK\n").await?,
        Err(e) => writer.write_all(format!("ERROR {e}\n").as_bytes()).await?,
    }

    Ok(())
}

fn parse_command(line: &str) -> io::Result<(LightCommand, oneshot::Receiver<Result<(), String>>)> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    let (tx, rx) = oneshot::channel();

    let command = match parts.as_slice() {
        ["on"] => LightCommand::On(tx),
        ["off"] => LightCommand::Off(tx),
        ["set", val] => {
            let v = parse_bounded(val, 0, 100, "brightness")? as u8;
            LightCommand::SetBrightness(v, tx)
        }
        ["step", val] => {
            let v = parse_bounded(val, -100, 100, "step")? as i16;
            LightCommand::StepBrightness(v, tx)
        }
        ["color", hue, sat] => {
            let h = parse_bounded(hue, 0, 360, "hue")? as u16;
            let s = parse_bounded(sat, 0, 100, "saturation")? as u8;
            LightCommand::SetColor(h, s, tx)
        }
        ["white"] => LightCommand::White(tx),
        ["refresh"] | ["poll"] => LightCommand::Refresh(tx),
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "commands: on, off, set <0-100>, step <-100..100>, color <0-360> <0-100>, white, refresh",
            ));
        }
    };

    Ok((command, rx))
}

fn parse_bounded(val: &str, min: i32, max: i32, name: &str) -> io::Result<i32> {
    let v = val.parse::<i32>().map_err(|_| {
        io::Error::new(io::ErrorKind::InvalidInput, format!("invalid {name}: {val}"))
    })?;
    if !(min..=max).contains(&v) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must be {min}..{max}"),
        ));
    }
    Ok(v)
}

pub async fn send_command(socket_path: &str, command: &str) -> io::Result<String> {
    let mut stream = UnixStream::connect(socket_path).await?;
    stream
        .write_all(format!("{command}\n").as_bytes())
        .await?;
    let mut response = String::new();
    BufReader::new(stream).read_line(&mut response).await?;
    Ok(response)
}
