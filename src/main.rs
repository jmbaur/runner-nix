mod adapter;
mod cli;

use adapter::get_adapter;
use anyhow;
use clap::Parser;
use cli::Args;
use futures::future::select_ok;
use std::process::Command;
use systemd::daemon;
use tokio;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    let mut sh = Command::new("sh");
    let mut cmd = sh.arg("-c");
    cmd = cmd.arg(args.command);

    let adapter = match get_adapter(args.adapter) {
        Some(a) => a,
        None => anyhow::bail!("no matching adapter found"),
    };

    let fds = daemon::listen_fds(true)?;
    let accepting_listeners: Vec<_> = match fds.len() {
        i32::MIN..=-1 => unreachable!(),
        0 => anyhow::bail!("did not get one systemd socket"),
        1..=10 => fds
            .iter()
            .map(|fd| {
                let std_listener = daemon::tcp_listener(fd).unwrap();
                std_listener.set_nonblocking(true).unwrap();
                let listener = TcpListener::from_std(std_listener).unwrap();
                Box::pin(async move { listener.accept().await })
            })
            .collect(),
        11..=i32::MAX => anyhow::bail!("got too many systemd sockets"),
    };

    let (stream, _) = select_ok(accepting_listeners).await?.0;

    if !adapter.authenticate(stream).await? {
        anyhow::bail!("adapter not authenticated");
    }

    adapter.setup_environment().await?;

    cmd.spawn()?.wait()?;

    Ok(())
}
