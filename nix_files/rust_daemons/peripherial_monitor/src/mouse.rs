use hidapi::{HidApi, HidDevice};

pub const KEYCHRON_VENDOR_ID: u16 = 0x3434;
pub const KEYCHRON_PRODUCT_IDS: &[u16] = &[
    0xD030, // Keychron Link (M6 / 2.4G dongle)
    0xD034, // Keychron M3/M6 wireless dongle
    0xD037, // Keychron wired/charging connection
    0xD028, // Keychron Ultra-Link receiver
    0xD048, // Keychron M5/M6 wired
];

pub struct KeychronMonitor;

impl KeychronMonitor {
    /// Attempts to find and open Keychron HID interfaces.
    pub fn open_devices(api: &HidApi) -> Vec<HidDevice> {
        let mut devices = Vec::new();

        for dev_info in api.device_list() {
            if dev_info.vendor_id() == KEYCHRON_VENDOR_ID {
                let matches_pid = KEYCHRON_PRODUCT_IDS.contains(&dev_info.product_id());
                let prod_str = dev_info.product_string().unwrap_or("");
                let is_keychron = matches_pid || prod_str.to_lowercase().contains("keychron");

                if is_keychron {
                    if let Ok(dev) = dev_info.open_device(api) {
                        devices.push(dev);
                    }
                }
            }
        }

        devices
    }

    /// Reads incoming passive push reports from all open Keychron interfaces.
    /// The Keychron M6 pushes battery reports when powered on/off or when the battery percentage drops.
    pub fn read_reports(devices: &mut [HidDevice], timeout_ms: i32) -> Option<u8> {
        let mut parsed_battery = None;

        for dev in devices.iter_mut() {
            let mut buf = [0u8; 64];
            if let Ok(n) = dev.read_timeout(&mut buf, timeout_ms) {
                if n > 0 {
                    let slice = &buf[..n];

                    // Format 1: 0x54 report from Keychron wireless protocol (byte 5 is battery %)
                    if slice[0] == 0x54 && n >= 6 {
                        let val = slice[5];
                        if (1..=100).contains(&val) {
                            println!("[Keychron M6] Parsed battery (0x54 push update): {}%", val);
                            parsed_battery = Some(val);
                        }
                    }

                    // Format 2: 0xB4 report
                    if slice[0] == 0xB4 && n > 20 && slice[1] == 0x06 {
                        let raw = slice[20];
                        let val = if raw > 100 { raw.saturating_sub(100) } else { raw };
                        if (1..=100).contains(&val) {
                            println!("[Keychron M6] Parsed battery (0xB4 report): {}%", val);
                            parsed_battery = Some(val);
                        }
                    }

                    // Format 3: [0x00|0x01, battery, 0x02, 0x02] sequence
                    for i in 0..n.saturating_sub(3) {
                        if (slice[i] == 0x00 || slice[i] == 0x01)
                            && slice[i + 2] == 0x02
                            && slice[i + 3] == 0x02
                        {
                            let val = slice[i + 1];
                            if (1..=100).contains(&val) {
                                println!("[Keychron M6] Parsed battery (pattern match): {}%", val);
                                parsed_battery = Some(val);
                            }
                        }
                    }
                }
            }
        }

        parsed_battery
    }
}
