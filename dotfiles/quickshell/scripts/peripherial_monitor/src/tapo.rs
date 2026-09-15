use std::env;

use tapo::{ApiClient, ColorLightHandler};

use crate::state::{current_unix_time, LightState, LightStatus};

type TapoResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

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

        if email.trim().is_empty() || password.trim().is_empty() || ip.trim().is_empty() {
            return Err("TAPO_EMAIL, TAPO_PASSWORD, and TAPO_IP must be set".into());
        }

        let device = ApiClient::new(email, password).l530(ip).await?;
        Ok(Self { device })
    }

    pub async fn read_state(&self) -> TapoResult<LightState> {
        let info = self.device.get_device_info().await?;
        let color_mode_is_temperature = info.color_temp > 0;

        Ok(LightState {
            status: LightStatus::Connected,
            device_on: info.device_on,
            brightness: info.brightness,
            hue: if color_mode_is_temperature {
                0
            } else {
                info.hue.unwrap_or(30)
            },
            saturation: if color_mode_is_temperature {
                0
            } else {
                info.saturation.unwrap_or(0).min(u8::MAX as u16) as u8
            },
            updated: current_unix_time(),
        })
    }

    pub async fn on(&self) -> TapoResult<()> {
        self.device.on().await?;
        Ok(())
    }

    pub async fn off(&self) -> TapoResult<()> {
        self.device.off().await?;
        Ok(())
    }

    pub async fn set_brightness(&self, brightness: u8) -> TapoResult<()> {
        self.device.set_brightness(brightness).await?;
        Ok(())
    }

    pub async fn set_color(&self, hue: u16, saturation: u8) -> TapoResult<()> {
        self.device.set_hue_saturation(hue, saturation).await?;
        Ok(())
    }

    pub async fn set_white(&self) -> TapoResult<()> {
        self.device.set_color_temperature(4000).await?;
        Ok(())
    }

    pub async fn execute(&self, action: LightAction) -> TapoResult<()> {
        match action {
            LightAction::On => self.on().await,
            LightAction::Off => self.off().await,
            LightAction::SetBrightness(value) => self.set_brightness(value).await,
            LightAction::SetColor(hue, saturation) => self.set_color(hue, saturation).await,
            LightAction::White => self.set_white().await,
        }
    }
}

pub fn disconnected_state(previous: &LightState) -> LightState {
    let mut state = previous.clone();
    state.status = LightStatus::Disconnected;
    state.updated = current_unix_time();
    state
}
