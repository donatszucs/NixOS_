use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub const PERIPHERALS_JSON_PATH: &str = "/tmp/peripherals.json";
pub const KEYCHRON_BATTERY_TXT_PATH: &str = "/tmp/keychron_battery.txt";
pub const PERSISTENT_CACHE_TMP_PATH: &str = "/tmp/peripheral_state_cache.json";

pub fn current_unix_time() -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct PeripheralState {
    pub mouse: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mouse_updated: Option<u64>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PersistentBatteryCache {
    pub mouse: Option<u8>,
    #[serde(default)]
    pub mouse_updated: Option<u64>,
}

impl Default for PersistentBatteryCache {
    fn default() -> Self {
        Self {
            mouse: None,
            mouse_updated: None,
        }
    }
}

pub struct StateCache {
    json_path: PathBuf,
    current_state: PeripheralState,
    last_known: PersistentBatteryCache,
}

impl StateCache {
    fn get_state_dir_path() -> Option<PathBuf> {
        if let Ok(home) = std::env::var("HOME") {
            let dir = PathBuf::from(home).join(".local/state/peripheral_monitor");
            let _ = fs::create_dir_all(&dir);
            Some(dir.join("state.json"))
        } else {
            None
        }
    }

    pub fn new() -> Self {
        let last_known = Self::load_persisted();
        let initial_state = PeripheralState {
            mouse: last_known.mouse,
            mouse_updated: last_known.mouse_updated,
        };
        let cache = Self {
            json_path: PathBuf::from(PERIPHERALS_JSON_PATH),
            current_state: initial_state,
            last_known,
        };
        cache.save_persisted();
        cache
    }

    pub fn load_persisted() -> PersistentBatteryCache {
        // 1. Try ~/.local/state/peripheral_monitor/state.json first
        if let Some(user_path) = Self::get_state_dir_path() {
            if let Ok(file) = File::open(&user_path) {
                if let Ok(state) = serde_json::from_reader(file) {
                    return state;
                }
            }
        }

        // 2. Try /tmp/peripheral_state_cache.json fallback
        let tmp_path = Path::new(PERSISTENT_CACHE_TMP_PATH);
        if let Ok(file) = File::open(tmp_path) {
            if let Ok(state) = serde_json::from_reader(file) {
                return state;
            }
        }

        PersistentBatteryCache::default()
    }

    pub fn save_persisted(&self) {
        // 1. Save to ~/.local/state/peripheral_monitor/state.json
        if let Some(user_path) = Self::get_state_dir_path() {
            if let Ok(file) = File::create(&user_path) {
                let _ = serde_json::to_writer_pretty(file, &self.last_known);
            }
        }

        // 2. Save to /tmp/peripheral_state_cache.json
        let tmp_path = Path::new(PERSISTENT_CACHE_TMP_PATH);
        if let Ok(file) = File::create(tmp_path) {
            let _ = serde_json::to_writer_pretty(file, &self.last_known);
        }
    }

    pub fn get_state(&self) -> &PeripheralState {
        &self.current_state
    }

    /// Update state and flush to disk.
    /// Updates persistent battery cache when new valid reading is present.
    pub fn update(&mut self, mut new_state: PeripheralState) -> io::Result<bool> {
        let mut cache_changed = false;

        if let Some(mouse_lvl) = new_state.mouse {
            let now = current_unix_time();
            if self.last_known.mouse != Some(mouse_lvl) {
                self.last_known.mouse = Some(mouse_lvl);
                self.last_known.mouse_updated = Some(now);
                cache_changed = true;
            }
            if new_state.mouse_updated.is_none() {
                new_state.mouse_updated = self.last_known.mouse_updated.or(Some(now));
            }
        }

        if cache_changed {
            self.save_persisted();
        }

        if self.current_state == new_state {
            return Ok(false);
        }

        self.current_state = new_state;
        self.flush()?;
        Ok(true)
    }

    pub fn flush(&self) -> io::Result<()> {
        let json_bytes = serde_json::to_vec_pretty(&self.current_state)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        // Write directly to preserve inode so inotify file watchers always get notified
        {
            let mut file = fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .open(&self.json_path)?;
            file.write_all(&json_bytes)?;
            file.write_all(b"\n")?;
            file.flush()?;
        }

        // Update /tmp/keychron_battery.txt for backwards compatibility
        let updated_time = self.current_state.mouse_updated.unwrap_or_else(current_unix_time);
        let mouse_txt = match self.current_state.mouse {
            Some(lvl) => format!("{}%\nLast updated: {}\n", lvl, updated_time),
            None => format!("Disconnected\nLast updated: {}\n", updated_time),
        };
        if let Ok(mut f) = fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(KEYCHRON_BATTERY_TXT_PATH)
        {
            let _ = f.write_all(mouse_txt.as_bytes());
            let _ = f.flush();
        }

        Ok(())
    }
}
