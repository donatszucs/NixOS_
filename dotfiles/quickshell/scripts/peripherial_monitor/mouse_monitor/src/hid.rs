use hidapi::{DeviceInfo, HidApi, HidDevice};

pub const KEYCHRON_VENDOR_ID: u16 = 0x3434;

pub const KEYCHRON_PRODUCT_IDS: &[u16] = &[
    0xD028, // Ultra-Link 8K receiver
    0xD049, // Keychron M6 8K
    0xD030, // Link 1K dongle
    0xD034, // Wireless dongle
    0xD037, // Wired/charging
    0xD048, // M5/M6/M6S wired
    0xD038, // M6 4K
    0xD039, // M6 wired
    0xD033, // M3 wireless
    0xD03F, // M6
    0xD06F, // G5
];

const REPORT_ID_CMD: u8 = 0xB3;
const REPORT_ID_RESP: u8 = 0xB4;
const CMD_STATUS: u8 = 0x06;
const REPORT_SIZE: usize = 64;
const BATTERY_OFFSET: usize = 20;

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct MouseData {
    pub battery: u8,
    pub charging: bool,
}

/// Parse a raw battery byte into (level, charging).
fn parse_battery_byte(raw: u8) -> Option<(u8, bool)> {
    if (raw & 0x80) != 0 {
        let masked = raw & 0x7F;
        if (1..=100).contains(&masked) {
            return Some((masked, true));
        }
        if raw > 100 {
            let alt = raw - 100;
            if (1..=100).contains(&alt) {
                return Some((alt, true));
            }
        }
        None
    } else if raw > 100 {
        let alt = raw - 100;
        if (1..=100).contains(&alt) {
            Some((alt, true))
        } else {
            None
        }
    } else if (1..=100).contains(&raw) {
        Some((raw, false))
    } else {
        None
    }
}

fn is_keychron_mouse(dev_info: &DeviceInfo) -> bool {
    if dev_info.vendor_id() != KEYCHRON_VENDOR_ID {
        return false;
    }
    let pid = dev_info.product_id();
    let prod = dev_info.product_string().unwrap_or("").to_lowercase();
    if prod.contains("keyboard") || prod.contains("k8") || prod.contains("q1") {
        return false;
    }
    KEYCHRON_PRODUCT_IDS.contains(&pid)
        || (pid & 0xFF00) == 0xD000
        || prod.contains("mouse")
        || prod.contains("ultra-link")
        || prod.contains("link")
        || prod.contains("m6")
        || prod.contains("m6s")
}

struct KeychronInterface {
    device: HidDevice,
    is_control: bool,
    is_primary_control: bool,
}

impl KeychronInterface {
    fn query_status(&mut self) -> Option<MouseData> {
        let mut cmd = [0u8; REPORT_SIZE];
        cmd[0] = REPORT_ID_CMD;
        cmd[1] = CMD_STATUS;

        if self.device.write(&cmd).is_err() {
            let _ = self.device.send_feature_report(&cmd);
        }

        let mut buf = [0u8; REPORT_SIZE];
        for _ in 0..3 {
            match self.device.read_timeout(&mut buf, 100) {
                Ok(n) if n > 0 => {
                    if let Some(data) = Self::parse_report(&buf[..n]) {
                        return Some(data);
                    }
                }
                Ok(_) => continue,
                Err(_) => break,
            }
        }
        None
    }

    fn parse_report(slice: &[u8]) -> Option<MouseData> {
        if slice.is_empty() {
            return None;
        }
        // 0xB4 status report
        if slice[0] == REPORT_ID_RESP && slice.len() > BATTERY_OFFSET {
            let (battery, charging) = parse_battery_byte(slice[BATTERY_OFFSET])?;
            return Some(MouseData { battery, charging });
        }
        // 0x54 push update (legacy M6 1K dongle)
        if slice[0] == 0x54 && slice.len() >= 6 {
            let (battery, charging) = parse_battery_byte(slice[5])?;
            return Some(MouseData { battery, charging });
        }
        None
    }
}

pub struct KeychronMonitor {
    interfaces: Vec<KeychronInterface>,
    pub mouse_name: String,
}

impl KeychronMonitor {
    pub fn is_connected(&self) -> bool {
        !self.interfaces.is_empty()
    }

    pub fn open(api: &HidApi) -> Self {
        let mut interfaces = Vec::new();
        let mut mouse_name = "Keychron M6S".to_string();

        for dev_info in api.device_list() {
            if !is_keychron_mouse(dev_info) {
                continue;
            }
            let iface_num = dev_info.interface_number();
            let usage_page = dev_info.usage_page();
            let pid = dev_info.product_id();
            let prod = dev_info.product_string().unwrap_or("Keychron Mouse").to_string();

            if pid == 0xD028 || prod.to_lowercase().contains("ultra-link") {
                mouse_name = "Keychron M6S".to_string();
            } else if mouse_name != "Keychron M6S" && !prod.is_empty() {
                mouse_name = prod.clone();
            }

            let is_primary_control = iface_num == 4 || usage_page == 0xffc1;
            let is_control = is_primary_control || (iface_num > 1 && usage_page >= 0xff00);

            // Skip mouse motion (iface 0) and keyboard (iface 1)
            if iface_num == 0 || iface_num == 1 {
                continue;
            }

            if let Ok(dev) = dev_info.open_device(api) {
                interfaces.push(KeychronInterface {
                    device: dev,
                    is_control,
                    is_primary_control,
                });
            }
        }

        // Fallback: try all matching devices if filtered selection found nothing
        if interfaces.is_empty() {
            for dev_info in api.device_list() {
                if is_keychron_mouse(dev_info) {
                    if let Ok(dev) = dev_info.open_device(api) {
                        interfaces.push(KeychronInterface {
                            device: dev,
                            is_control: true,
                            is_primary_control: true,
                        });
                    }
                }
            }
        }

        Self {
            interfaces,
            mouse_name,
        }
    }

    pub fn query_status(&mut self) -> Option<MouseData> {
        for iface in self.interfaces.iter_mut() {
            if iface.is_primary_control {
                if let Some(data) = iface.query_status() {
                    return Some(data);
                }
            }
        }
        for iface in self.interfaces.iter_mut() {
            if iface.is_control && !iface.is_primary_control {
                if let Some(data) = iface.query_status() {
                    return Some(data);
                }
            }
        }
        None
    }

    pub fn read_passive_reports(&mut self, timeout_ms: i32) -> Result<Option<MouseData>, ()> {
        if self.interfaces.is_empty() {
            return Err(());
        }
        let mut err_count = 0;
        let total = self.interfaces.len();
        for iface in self.interfaces.iter_mut() {
            let mut buf = [0u8; REPORT_SIZE];
            match iface.device.read_timeout(&mut buf, timeout_ms) {
                Ok(n) if n > 0 => {
                    if let Some(data) = KeychronInterface::parse_report(&buf[..n]) {
                        return Ok(Some(data));
                    }
                }
                Ok(_) => {}
                Err(_) => err_count += 1,
            }
        }
        if err_count == total {
            Err(())
        } else {
            Ok(None)
        }
    }
}
