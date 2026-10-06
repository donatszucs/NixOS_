use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Write;
use std::process::{Command, Stdio};

const STATE_PATH: &str = "/tmp/phone_state.json";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatteryState {
    pub level: i32,
    pub charging: bool,
    pub available: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CellularState {
    pub signal: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhoneState {
    pub connected: bool,
    #[serde(rename = "deviceId")]
    pub device_id: String,
    pub name: String,
    pub ip: String,
    pub battery: BatteryState,
    pub cellular: CellularState,
}

impl Default for PhoneState {
    fn default() -> Self {
        Self {
            connected: false,
            device_id: String::new(),
            name: "No Phone Connected".to_string(),
            ip: String::new(),
            battery: BatteryState {
                level: -1,
                charging: false,
                available: false,
            },
            cellular: CellularState { signal: -1 },
        }
    }
}

fn run_cmd(program: &str, args: &[&str]) -> Option<String> {
    let mut cmd = Command::new(program);
    cmd.args(args);
    cmd.env(
        "PATH",
        format!(
            "/run/current-system/sw/bin:/etc/profiles/per-user/{}/bin:{}",
            std::env::var("USER").unwrap_or_default(),
            std::env::var("PATH").unwrap_or_default()
        ),
    );
    let output = cmd.output().ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        None
    }
}

/// Decodes busctl string representation, including octal escape sequences \ooo
fn decode_busctl_string(raw: &str) -> String {
    let trimmed = raw.trim();
    let inner = match (trimmed.find('"'), trimmed.rfind('"')) {
        (Some(start), Some(end)) if start < end => &trimmed[start + 1..end],
        _ => trimmed,
    };

    let mut bytes: Vec<u8> = Vec::new();
    let chars: Vec<char> = inner.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '\\' && i + 3 < chars.len() && chars[i + 1].is_ascii_digit() && chars[i + 2].is_ascii_digit() && chars[i + 3].is_ascii_digit() {
            let octal_str: String = chars[i + 1..=i + 3].iter().collect();
            if let Ok(b) = u8::from_str_radix(&octal_str, 8) {
                bytes.push(b);
                i += 4;
                continue;
            }
        }
        let mut buf = [0u8; 4];
        let encoded = chars[i].encode_utf8(&mut buf);
        bytes.extend_from_slice(encoded.as_bytes());
        i += 1;
    }

    String::from_utf8_lossy(&bytes).to_string()
}

fn extract_quoted_strings(raw: &str) -> Vec<String> {
    let mut results = Vec::new();
    let mut in_quote = false;
    let mut current = String::new();

    for c in raw.chars() {
        if c == '"' {
            if in_quote {
                results.push(current.clone());
                current.clear();
                in_quote = false;
            } else {
                in_quote = true;
            }
        } else if in_quote {
            current.push(c);
        }
    }
    results
}

fn get_active_device_id() -> Option<String> {
    // 1. Try reachable + paired devices first
    if let Some(out) = run_cmd(
        "busctl",
        &["--user", "call", "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices", "bb", "true", "true"],
    ) {
        let devs = extract_quoted_strings(&out);
        if let Some(dev) = devs.into_iter().next() {
            if !dev.is_empty() {
                return Some(dev);
            }
        }
    }

    // 2. Try any paired device
    if let Some(out) = run_cmd(
        "busctl",
        &["--user", "call", "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices", "bb", "false", "true"],
    ) {
        let devs = extract_quoted_strings(&out);
        if let Some(dev) = devs.into_iter().next() {
            if !dev.is_empty() {
                return Some(dev);
            }
        }
    }

    // 3. Fallback to kdeconnect-cli
    if let Some(out) = run_cmd("kdeconnect-cli", &["-a", "--id-only"]) {
        for line in out.lines() {
            let trimmed = line.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
    }

    None
}

fn extract_ip(raw: &str) -> String {
    for word in raw.split(|c: char| !c.is_alphanumeric() && c != '.') {
        let parts: Vec<&str> = word.split('.').collect();
        if parts.len() == 4 && parts.iter().all(|p| p.parse::<u8>().is_ok()) {
            return word.to_string();
        }
    }
    String::new()
}

fn query_phone_state() -> PhoneState {
    let dev = match get_active_device_id() {
        Some(d) => d,
        None => return PhoneState::default(),
    };

    let dev_path = format!("/modules/kdeconnect/devices/{}", dev);

    // Name
    let name = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &dev_path, "org.kde.kdeconnect.device", "name"],
    )
    .map(|s| decode_busctl_string(&s))
    .unwrap_or_else(|| "Phone".to_string());

    // isReachable
    let connected = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &dev_path, "org.kde.kdeconnect.device", "isReachable"],
    )
    .map(|s| s.contains("true"))
    .unwrap_or(false);

    // IP
    let ip = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &dev_path, "org.kde.kdeconnect.device", "reachableAddresses"],
    )
    .map(|s| extract_ip(&s))
    .unwrap_or_default();

    // Battery
    let bat_path = format!("{}/battery", dev_path);
    let level = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &bat_path, "org.kde.kdeconnect.device.battery", "charge"],
    )
    .and_then(|s| {
        s.split_whitespace()
            .last()
            .and_then(|v| v.parse::<i32>().ok())
    })
    .unwrap_or(-1);

    let charging = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &bat_path, "org.kde.kdeconnect.device.battery", "isCharging"],
    )
    .map(|s| s.contains("true"))
    .unwrap_or(false);

    // Cellular
    let conn_path = format!("{}/connectivity_report", dev_path);
    let signal = run_cmd(
        "busctl",
        &["--user", "get-property", "org.kde.kdeconnect", &conn_path, "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength"],
    )
    .and_then(|s| {
        s.split_whitespace()
            .last()
            .and_then(|v| v.parse::<i32>().ok())
    })
    .unwrap_or(-1);

    PhoneState {
        connected,
        device_id: dev,
        name: if name.is_empty() { "Phone".to_string() } else { name },
        ip,
        battery: BatteryState {
            level,
            charging,
            available: level >= 0,
        },
        cellular: CellularState { signal },
    }
}

fn write_and_print_state(state: &PhoneState) {
    if let Ok(json) = serde_json::to_string_pretty(state) {
        if let Ok(mut file) = fs::File::create(STATE_PATH) {
            let _ = writeln!(file, "{}", json);
        }
        println!("{}", json);
    }
}

fn ring_phone(dev: &str) {
    let path = format!("/modules/kdeconnect/devices/{}/findmyphone", dev);
    let _ = run_cmd(
        "busctl",
        &["--user", "call", "org.kde.kdeconnect", &path, "org.kde.kdeconnect.device.findmyphone", "ring"],
    );
}

fn browse_phone(dev: &str) {
    let path = format!("/modules/kdeconnect/devices/{}/sftp", dev);
    let res = run_cmd(
        "busctl",
        &["--user", "call", "org.kde.kdeconnect", &path, "org.kde.kdeconnect.device.sftp", "startBrowsing"],
    );
    if res.is_none() {
        let _ = run_cmd("kdeconnect-cli", &["-d", dev, "--mount"]);
        let uid = run_cmd("id", &["-u"]).unwrap_or_else(|| "1000".to_string());
        let mnt = format!("/run/user/{}/{}", uid.trim(), dev);
        let _ = Command::new("xdg-open").arg(mnt).spawn();
    }
}

fn ping_phone(dev: &str) {
    let _ = run_cmd("kdeconnect-cli", &["-d", dev, "--ping"]);
}

fn open_app() {
    let _ = Command::new("kdeconnect-app")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let action = args.get(1).map(|s| s.as_str()).unwrap_or("poll");

    match action {
        "ring" => {
            if let Some(dev) = get_active_device_id() {
                ring_phone(&dev);
            }
        }
        "browse" | "mount" => {
            if let Some(dev) = get_active_device_id() {
                browse_phone(&dev);
            }
        }
        "ping" => {
            if let Some(dev) = get_active_device_id() {
                ping_phone(&dev);
            }
        }
        "app" => {
            open_app();
        }
        "poll" | _ => {
            let state = query_phone_state();
            write_and_print_state(&state);
        }
    }
}
