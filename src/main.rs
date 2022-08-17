mod adapter;
mod cli;

use anyhow;
use clap::Parser;
use futures::future::select_ok;
use hyper::{http::StatusCode, server::conn::Http, service::service_fn, Body, Response};
use log::{debug, error, info};
use std::process::Command;
use systemd::daemon;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::builder().format_timestamp(None).init();

    let args = cli::Args::parse();
    debug!("parsed cli args: {:?}", args);

    let fds = daemon::listen_fds(true)?;
    debug!("systemd passed {} sockets to the program", fds.len());

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
    debug!("first accepted stream: {:?}", stream);

    let service = service_fn(move |req| {
        let mut sh = Command::new("sh");
        let command = args.command.clone();
        let adp = args.adapter.clone();
        async move {
            let adapter_res = match adp.as_str() {
                "none" => Ok((true, None)),
                "github" => adapter::github::auth_and_env(req).await,
                _ => Ok((false, None)),
            };
            match adapter_res {
                Ok((authenticated, env)) => {
                    if !authenticated {
                        error!("client not authenticated");
                        Ok::<_, hyper::Error>(
                            Response::builder()
                                .status(StatusCode::UNAUTHORIZED)
                                .body(Body::empty())
                                .expect("unable to create response"),
                        )
                    } else {
                        info!("client authenticated, preparing environment and starting run");
                        tokio::spawn(async move {
                            let mut cmd = sh.arg("-c");
                            cmd = cmd.arg(command);
                            if let Some(e) = env {
                                cmd = cmd.env("RUN_REF", e.ref_field.clone());
                                cmd = cmd.env("RUN_URL", e.url.clone());
                                info!("setting adapter environment");
                                debug!("adapter environment: {:?}", e);
                            }
                            info!("starting run");
                            if let Ok(mut run) = cmd.spawn() {
                                _ = run.wait();
                            }
                        });
                        Ok::<_, hyper::Error>(Response::new(Body::empty()))
                    }
                }
                Err(e) => {
                    error!("failed to get adapter authentication status and environment: {e}");
                    Ok::<_, hyper::Error>(
                        Response::builder()
                            .status(StatusCode::INTERNAL_SERVER_ERROR)
                            .body(Body::empty())
                            .expect("unable to create response"),
                    )
                }
            }
        }
    });

    if let Err(err) = Http::new().serve_connection(stream, service).await {
        error!("error serving connection: {:?}", err);
    }

    Ok(())
}
