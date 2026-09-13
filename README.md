## Installation

```bash
git clone https://github.com/donatszucs/NixOS_.git ~/nixos-config
cd ~/nixos-config
chmod +x setup.sh && ./setup.sh
sudo nixos-rebuild switch --flake ./nix_files#doni
```

## Tapo Light Setup

The light switch is controlled by the Rust `peripherial_monitor` daemon. Its
credentials are read from a user-only environment file and are not stored in
the repository.

After a fresh install, create the file before starting the service:

```bash
install -d -m 700 ~/.config/peripheral-monitor
${EDITOR:-nano} ~/.config/peripheral-monitor/tapo.env
chmod 600 ~/.config/peripheral-monitor/tapo.env
```

Add these values using the email, password, and local IP address for the Tapo
light:

```ini
TAPO_EMAIL=your-tapo-email
TAPO_PASSWORD=your-tapo-password
TAPO_IP=192.168.1.100
```

Apply the service configuration and restart the daemon:

```bash
sudo nixos-rebuild switch --flake ./nix_files#doni
systemctl --user daemon-reload
systemctl --user restart peripheral-monitor
systemctl --user status peripheral-monitor
```

Verify the daemon and shared state:

```bash
cat /tmp/peripherals.json
ls -l /tmp/peripheral_monitor.sock
```

The light controls use the daemon client:

```bash
peripherial_monitor light on
peripherial_monitor light off
peripherial_monitor light set 50
peripherial_monitor light color 180 100
peripherial_monitor light white
```

Quickshell reads light and mouse state from `/tmp/peripherals.json` and updates
when the daemon changes it. Reload Quickshell after installation with
`SUPER+Q` or:

```bash
pkill quickshell
quickshell &
```

The Python Tapo script and its virtual-environment dependencies are no longer
needed. The Python environment remains only for the headset battery monitor (that is disabled):

```bash
cd ~/nixos-config/scripts/scriptsEnv
uv sync
```

## Maintenance

Delete old builds:

```bash
sudo nix-collect-garbage --delete-older-than 5d
```

List generations:

```bash
sudo nixos-rebuild list-generations
```
