use std::env;

use tapo::{ApiClient, ColorLightHandler};

use crate::{unix_now, LightState, LightStatus};

type TapoResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

#[derive(Debug, Clone, Copy)]
pub enum LightAction {
    On,
    Off,
    SetBrightness(u8),
    SetColor(u16, u8),
    White,
}

pub struct TapoController {
    device: ColorLightHandler,
}

impl TapoController {
    pub async fn connect_from_env() -> TapoResult<Self> {
        let email = env::var("TAPO_EMAIL")?;
        let password = env::var("TAPO_PASSWORD")?;
        let ip = env::var("TAPO_IP")?;

        let email = email.trim().to_string();
        let password = password.trim().to_string();
        let ip = ip.trim().to_string();

        if email.is_empty() || password.is_empty() || ip.is_empty() {
            return Err("TAPO_EMAIL, TAPO_PASSWORD, and TAPO_IP must be set".into());
        }

        let device = ApiClient::new(email, password).l530(ip).await?;
        Ok(Self { device })
    }

    pub async fn read_state(&mut self) -> TapoResult<LightState> {
        let info = match self.device.get_device_info().await {
            Ok(info) => info,
            Err(e) => {
                // Try session refresh on error
                let err_str = e.to_string();
                if err_str.contains("SESSION") || err_str.contains("Unauthorized") || err_str.contains("timeout") {
                    let _ = self.device.refresh_session().await;
                    self.device.get_device_info().await?
                } else {
                    return Err(e.into());
                }
            }
        };

        let is_temp_mode = info.color_temp > 0;

        Ok(LightState {
            status: LightStatus::Connected,
            device_on: info.device_on,
            brightness: info.brightness,
            hue: if is_temp_mode { 0 } else { info.hue.unwrap_or(30) },
            saturation: if is_temp_mode {
                0
            } else {
                info.saturation.unwrap_or(0).min(u8::MAX as u16) as u8
            },
            updated: unix_now(),
        })
    }

    async fn run_action(dev: &ColorLightHandler, action: LightAction) -> Result<(), tapo::Error> {
        match action {
            LightAction::On => dev.on().await,
            LightAction::Off => dev.off().await,
            LightAction::SetBrightness(v) => dev.set_brightness(v).await,
            LightAction::SetColor(h, s) => dev.set_hue_saturation(h, s).await,
            LightAction::White => dev.set_color_temperature(4000).await,
        }
    }

    pub async fn execute(&mut self, action: LightAction) -> TapoResult<()> {
        match Self::run_action(&self.device, action).await {
            Ok(_) => Ok(()),
            Err(e) => {
                // If action failed, try refreshing session and retry once
                let err_str = e.to_string();
                if err_str.contains("SESSION") || err_str.contains("Unauthorized") || err_str.contains("timeout") {
                    let _ = self.device.refresh_session().await;
                    Self::run_action(&self.device, action).await.map_err(|e2| -> Box<dyn std::error::Error + Send + Sync> { e2.into() })
                } else {
                    Err(e.into())
                }
            }
        }
    }
}
