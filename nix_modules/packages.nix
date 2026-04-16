{ config, pkgs, inputs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Flatpak support
  services.flatpak.enable = true;

  programs.nix-ld.enable = true;

  # KDE Connect for phone integration
  programs.kdeconnect.enable = true;
  
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        softrealtime = "auto";
        renice = 15;
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Steam for gaming
  programs.steam = {
    enable = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [

  # -- Network --
  networkmanagerapplet

  # -- Audio --
  blueman      # Bluetooth manager
  pavucontrol  # This is the GUI to control specific apps
  pamixer      # Helps with keybindings (optional but good)
  playerctl    # Media key support for various apps
    
  # -- Essential Tools --
  kitty             # Terminal (default for Hyprland, needed to start debugging)
  brightnessctl     # Screen brightness control
  ddcutil           # Control monitor settings like brightness, contrast, etc.
  libnotify        # Notification library
  pwvucontrol     # Pipewire volume control CLI
  input-remapper   # Input remapping service
  pkgs.uv          # Python package manager
  jq               # Command-line JSON processor
  quickshell        # A quick launcher for commands and scripts (like Rofi but for CLI)
  ffmpeg            # For video processing and screen recording
  baobab             # Disk usage analyzer
  wtype             # CLI keyboard input tool
  rbw               # CLI password manager
  pinentry-qt     # Qt5 pinentry for rbw
  usbutils          # For lsusb and other USB tools
  wlsunset          # Automatic color temperature adjustment based on time of day
  
  # -- Applications --
  vscode            
  google-chrome
  inputs.zen-browser.packages."${builtins.currentSystem}".default
  inputs.playit-nixos-module.packages."${builtins.currentSystem}".playit-cli
  spotify
  pkgs.vesktop
  discord
  qalculate-gtk
  texlive.combined.scheme-full
  teams-for-linux

  (prismlauncher.override {
    jdks = [ 
      jdk8 
      jdk17 
      jdk21 
      jdk25
    ];
  })


  # -- keyboard --
  wvkbd             # On-screen keyboard

  # -- Wallpapers & Screen Locking --
  hyprpaper         # Wallpaper utility
  hyprlock          # Screen locker

  # -- File Management --
  pkgs.thunar       # File manager
  pkgs.thunar-archive-plugin # Archive plugin for Thunar
  file-roller       # Archive manager GUI
  zip               # CLI zip tool
  unzip             # CLI unzip tool
  p7zip             # CLI 7z tool
  unar              # CLI unar tool

  # -- Screenshots / Clipboard --
  grim              # Screenshot tool
  slurp             # Select area for screenshot
  cliphist         # Clipboard manager backend
  wl-clipboard      # Clipboard manager

  # -- Task Management --
  btop              # The cool terminal one
  mission-center    # The Windows-style GUI one

  # -- Headset Control --
  hidapi            # HID access library (needed for HyperX Cloud II Wireless script)
  ];

  programs.bash.shellAliases = {
    mc-sv = "/home/doni/nixos-config/scripts/Minecraft/mc-server.sh";
  };

}
