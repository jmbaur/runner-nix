use async_trait::async_trait;
use hyper::server::conn::Http;
use hyper::service::service_fn;
use hyper::{Body, Request, Response};
use tokio::net::TcpStream;

pub fn get_adapter(adapter_string: String) -> Option<Box<dyn Adapter>> {
    match adapter_string.as_str() {
        "none" => Some(Box::new(NoneAdapter {})),
        _ => None,
    }
}

#[async_trait]
pub trait Adapter {
    async fn authenticate(&self, stream: TcpStream) -> anyhow::Result<bool>;
    async fn setup_environment(&self) -> anyhow::Result<()>;
}

pub struct NoneAdapter {}

async fn simple_response(_: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    Ok(Response::new(Body::from("OK")))
}

#[async_trait]
impl Adapter for NoneAdapter {
    async fn authenticate(&self, _stream: TcpStream) -> anyhow::Result<bool> {
        Http::new()
            .serve_connection(_stream, service_fn(simple_response))
            .await?;
        Ok(true)
    }
    async fn setup_environment(&self) -> anyhow::Result<()> {
        Ok(())
    }
}
