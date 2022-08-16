use anyhow::Result;
use hmac::{Hmac, Mac};
use hyper::{body, Body, Request};
use sha2::Sha256;
use std::env;

#[derive(Clone, Copy, Debug)]
pub struct Environment;

type HmacSha256 = Hmac<Sha256>;

// https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads#push
pub async fn github(req: Request<Body>) -> Result<(bool, Option<Environment>)> {
    let (parts, body) = req.into_parts();
    let authenticated = match (
        parts.headers.get("User-Agent"),
        parts.headers.get("X-GitHub-Event"),
        parts.headers.get("X-GitHub-Delivery"),
        parts.headers.get("X-Hub-Signature-256"),
    ) {
        (Some(user_agent), Some(github_event), Some(github_delivery), Some(hub_signature)) => {
            if !user_agent.to_str()?.starts_with("GitHub-Hookshot/") {
                false
            } else {
                println!("EVENT: {}", github_event.to_str()?);
                println!("DELIVERY: {}", github_delivery.to_str()?);

                let github_hmac_secret = env::var("GITHUB_HMAC_SECRET")?;
                let mut mac = HmacSha256::new_from_slice(github_hmac_secret.as_bytes())?;
                mac.update(&body::to_bytes(body).await?);

                mac.verify_slice(hub_signature.as_bytes()).is_ok()
            }
        }
        _ => false,
    };

    Ok((authenticated, None))
}
