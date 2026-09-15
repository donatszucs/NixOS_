use std::io;
use std::path::Path;
use std::os::unix::fs::PermissionsExt;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{mpsc, oneshot};

pub const SOCKET_PATH: &str = "/tmp/peripheral_monitor.sock";

#[derive(Debug)]
pub enum LightCommand {
    On(oneshot::Sender<Result<(), String>>),
    Off(oneshot::Sender<Result<(), String>>),
    SetBrightness(u8, oneshot::Sender<Result<(), String>>),
    StepBrightness(i16, oneshot::Sender<Result<(), String>>),
    SetColor(u16, u8, oneshot::Sender<Result<(), String>>),
    White(oneshot::Sender<Result<(), String>>),
}

pub async fn serve(socket_path: &Path, command_tx: mpsc::Sender<LightCommand>) -> io::Result<()> {
    let _ = std::fs::remove_file(socket_path);
    let listener = UnixListener::bind(socket_path)?;
    std::fs::set_permissions(socket_path, std::fs::Permissions::from_mode(0o600))?;

    loop {
        let (stream, _) = listener.accept().await?;
        let tx = command_tx.clone();
        tokio::spawn(async move {
            if let Err(error) = handle_client(stream, tx).await {
                eprintln!("[Light IPC] Client error: {error}");
            }
        });
    }
}

async fn handle_client(stream: UnixStream, command_tx: mpsc::Sender<LightCommand>) -> io::Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();

    let Some(line) = lines.next_line().await? else {
        return Ok(());
    };

    let (command, response_rx) = parse_command(line.trim())?;
    command_tx
        .send(command)
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "daemon command worker stopped"))?;

    let response = response_rx
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "daemon did not answer"))?;

    match response {
        Ok(()) => writer.write_all(b"OK\n").await?,
        Err(error) => {
            writer.write_all(format!("ERROR {error}\n").as_bytes()).await?;
        }
    }

    Ok(())
}

fn parse_command(line: &str) -> io::Result<(LightCommand, oneshot::Receiver<Result<(), String>>)> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    let (response_tx, response_rx) = oneshot::channel();

    let command = match parts.as_slice() {
        ["on"] => LightCommand::On(response_tx),
        ["off"] => LightCommand::Off(response_tx),
        ["set", value] => {
            let value = parse_bounded(value, 0, 100, "brightness")? as u8;
            LightCommand::SetBrightness(value, response_tx)
        }
        ["step", value] => {
            let value = parse_bounded(value, -100, 100, "brightness step")? as i16;
            LightCommand::StepBrightness(value, response_tx)
        }
        ["color", hue, saturation] => {
            let hue = parse_bounded(hue, 0, 360, "hue")? as u16;
            let saturation = parse_bounded(saturation, 0, 100, "saturation")? as u8;
            LightCommand::SetColor(hue, saturation, response_tx)
        }
        ["white"] => LightCommand::White(response_tx),
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "commands: on, off, set <0-100>, step <-100..100>, color <0-360> <0-100>, white",
            ));
        }
    };

    Ok((command, response_rx))
}

fn parse_bounded(value: &str, minimum: i32, maximum: i32, name: &str) -> io::Result<i32> {
    let parsed = value.parse::<i32>().map_err(|_| {
        io::Error::new(io::ErrorKind::InvalidInput, format!("invalid {name}: {value}"))
    })?;

    if !(minimum..=maximum).contains(&parsed) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must be between {minimum} and {maximum}"),
        ));
    }

    Ok(parsed)
}

pub async fn send_command(command: &str) -> io::Result<String> {
    let mut stream = UnixStream::connect(SOCKET_PATH).await?;
    stream.write_all(format!("{command}\n").as_bytes()).await?;
    let mut response = String::new();
    BufReader::new(stream).read_line(&mut response).await?;
    Ok(response)
}
