## Installation

```bash
git clone https://github.com/donatszucs/NixOS_.git ~/nixos-config
cd ~/nixos-config
chmod +x setup.sh && ./setup.sh
sudo nixos-rebuild switch --flake ./nix_files#doni
```

## Peripheral & Tapo Light Setup

The system includes two dedicated Rust daemons:
- `mouse_monitor`: Keychron mouse battery monitor (reads HID raw reports, status via `/tmp/mouse_state.json`)
- `light_controller`: Tapo smart bulb controller (state via `/tmp/light_state.json`)

### Tapo Light Credentials

Light credentials are read from a user-only environment file:

```bash
install -d -m 700 ~/.config/peripheral-monitor
${EDITOR:-nano} ~/.config/peripheral-monitor/tapo.env
chmod 600 ~/.config/peripheral-monitor/tapo.env
```

Add these values:

```ini
TAPO_EMAIL=your-tapo-email
TAPO_PASSWORD=your-tapo-password
TAPO_IP=192.168.1.100
```

Apply configuration and restart the daemons:

```bash
sudo nixos-rebuild switch --flake ./nix_files#doni
systemctl --user daemon-reload
systemctl --user restart mouse-monitor light-controller
systemctl --user status mouse-monitor light-controller
```

### CLI Commands

Mouse manual poll:
```bash
mouse_monitor poll
```

Light controls:
```bash
light_controller on
light_controller off
light_controller set 50
light_controller color 180 100
light_controller white
light_controller refresh
```

Quickshell reads state from `/tmp/mouse_state.json` and `/tmp/light_state.json`
and updates reactively when the daemons refresh them. Reload Quickshell with
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
