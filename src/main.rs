mod adapter;
mod cli;

use anyhow;
use clap::Parser;
use futures::future::select_ok;
use hyper::{http::StatusCode, server::conn::Http, service::service_fn, Body, Response};
use std::process::Command;
use systemd::daemon;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = cli::Args::parse();

    let fds = daemon::listen_fds(true)?;
    let accepting_listeners: Vec<_> = match fds.len() {
        i32::MIN..=-1 => unreachable!(),
        0 => anyhow::bail!("did not get one systemd socket"),
        1..=10 => fds
            .iter()
            .map(|fd| {
                let std_listener = daemon::tcp_listener(fd)?;
                std_listener.set_nonblocking(true)?;
                TcpListener::from_std(std_listener)
            })
            .filter(|x| x.is_ok())
            .map(|listener| Box::pin(async move { listener?.accept().await }))
            .collect(),
        11..=i32::MAX => anyhow::bail!("got too many systemd sockets"),
    };

    let (stream, _) = select_ok(accepting_listeners).await?.0;

    let service = service_fn(move |req| {
        let mut sh = Command::new("sh");
        let command = args.command.clone();
        let adapter = args.adapter.clone();
        async move {
            if let Ok((authenticated, environment)) = match adapter.as_str() {
                "none" => Ok((true, None)),
                "github" => adapter::github(req).await,
                _ => Ok((false, None)),
            } {
                if !authenticated {
                    Ok::<_, hyper::Error>(
                        Response::builder()
                            .status(StatusCode::UNAUTHORIZED)
                            .body(Body::empty())
                            .expect("unable to create response"),
                    )
                } else {
                    tokio::spawn(async move {
                        let mut cmd = sh.arg("-c");
                        cmd = cmd.arg(command);
                        if let Some(env) = environment {
                            println!("{:#?}", env)
                        }
                        if let Ok(mut run) = cmd.spawn() {
                            _ = run.wait();
                        }
                    });
                    Ok::<_, hyper::Error>(Response::new(Body::empty()))
                }
            } else {
                Ok::<_, hyper::Error>(
                    Response::builder()
                        .status(StatusCode::INTERNAL_SERVER_ERROR)
                        .body(Body::empty())
                        .expect("unable to create response"),
                )
            }
        }
    });

    if let Err(err) = Http::new().serve_connection(stream, service).await {
        println!("Error serving connection: {:?}", err);
    }

    Ok(())
}
