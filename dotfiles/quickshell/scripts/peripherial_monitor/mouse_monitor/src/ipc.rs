use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{mpsc, oneshot};

pub async fn serve_mouse(
    socket_path: &str,
    poll_tx: mpsc::Sender<oneshot::Sender<Result<(), String>>>,
) -> io::Result<()> {
    let path = Path::new(socket_path);
    let _ = std::fs::remove_file(path);
    let listener = UnixListener::bind(path)?;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;

    loop {
        let (stream, _) = listener.accept().await?;
        let tx = poll_tx.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, tx).await {
                eprintln!("[mouse_monitor] IPC client error: {e}");
            }
        });
    }
}

async fn handle_client(
    stream: UnixStream,
    poll_tx: mpsc::Sender<oneshot::Sender<Result<(), String>>>,
) -> io::Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();

    let Some(line) = lines.next_line().await? else {
        return Ok(());
    };

    let trimmed = line.trim();
    if trimmed == "poll" {
        let (tx, rx) = oneshot::channel();
        poll_tx
            .send(tx)
            .await
            .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "worker stopped"))?;
        let result = rx
            .await
            .map_err(|_| io::Error::new(io::ErrorKind::BrokenPipe, "worker did not respond"))?;
        match result {
            Ok(()) => writer.write_all(b"OK\n").await?,
            Err(e) => writer.write_all(format!("ERROR {e}\n").as_bytes()).await?,
        }
    } else {
        writer
            .write_all(b"ERROR unknown command (expected: poll)\n")
            .await?;
    }

    Ok(())
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
