# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  
  # Supported filesystems for the initrd (for mounting /boot and other partitions)
  boot.supportedFilesystems = ["ntfs"];
  
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Budapest";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "hu_HU.UTF-8";
    LC_IDENTIFICATION = "hu_HU.UTF-8";
    LC_MEASUREMENT = "hu_HU.UTF-8";
    LC_MONETARY = "hu_HU.UTF-8";
    LC_NAME = "hu_HU.UTF-8";
    LC_NUMERIC = "hu_HU.UTF-8";
    LC_PAPER = "hu_HU.UTF-8";
    LC_TELEPHONE = "hu_HU.UTF-8";
    LC_TIME = "hu_HU.UTF-8";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };


  # Configure console keymap
  console.keyMap = "hu";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable I2C kernel modules
  hardware.i2c.enable = true;

  # Enable GVFS for file management in Thunar and other GTK apps
  services.gvfs.enable = true;

  # 1. Enable firmware (Critical for WiFi/Bluetooth)
  hardware.enableAllFirmware = true;

  # 2. Bluetooth Settings
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Enable = "Source,Sink,Media,Socket"; # Allow all profiles (including keyboard/mouse HID)
        Experimental = true; # Show battery charge for supported devices
        JustWorksRepairing = "always"; # Helps with some devices that fail to pair
        # MultiProfile = "multiple";
      };
    };
  };

  # 3. Force load the kernel module (Driver)
  boot.kernelModules = [ "btusb" ];
  
  # Flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Flatpak support
  services.flatpak.enable = true;

  # Enable the graphics driver
  hardware.graphics.enable = true;

  # Load the Nvidia driver
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is usually required for Hyprland
    modesetting.enable = true;

    # The fix for your error:
    # Set this to true for RTX 2000 series or newer.
    # Set this to false for GTX 1000 series or older.
    open = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Ensure you are using the latest driver
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false; # Disable the old backend
  security.rtkit.enable = true;       # Recommended for audio scheduling
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # <--- This lets you use PulseAudio tools!
    # jack.enable = true; # Optional: For pro-audio tools
    extraConfig.pipewire."92-high-quality" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
      "default.clock.quantum" = 1024;
      "default.clock.min-quantum" = 32;
      "default.clock.max-quantum" = 2048;
      };
    };
  };
  # Enable Bluetooth audio support
  services.blueman.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.doni = {
    isNormalUser = true;
    description = "Doni";
    extraGroups = [ "networkmanager" "wheel" "i2c" "video" "input" "uinput" ];
    packages = with pkgs; [
      git
    ];
  };

  programs.nix-ld.enable = true;

  # Enable Hyprland
  programs.hyprland.enable = true;

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

  # Optional: Hint Electron apps to use Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable display manager with hyprlock
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "doni";
    };
    gdm = {
      enable = true;
    };
  };

  # Enable input remapper service
  services.input-remapper.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  
  # -- Wallpaper app --
  (
    makeDesktopItem {
      name = "Rofi Wallpaper Selector";
      desktopName = "Wallpaper Selector";
      comment = "Select a wallpaper";
      exec = "/home/doni/nixos-config/scripts/wallpaper-launcher.sh";
      terminal = false;
      type = "Application";
      categories = ["Utility"];
    }
  )
  # -- Network --
  networkmanagerapplet

  # -- Audio --
  blueman      # Bluetooth manager
  pavucontrol  # This is the GUI to control specific apps
  pamixer      # Helps with keybindings (optional but good)
  playerctl    # Media key support for various apps
    
  # -- Essential Tools --
  kitty             # Terminal (default for Hyprland, needed to start debugging)
  waybar            # Status bar (top bar)
  mako              # Notification daemon
  rofi              # Application launcher
  brightnessctl     # Screen brightness control
  ddcutil           # Control monitor settings like brightness, contrast, etc.
  libnotify        # Notification library
  pwvucontrol     # Pipewire volume control CLI
  input-remapper   # Input remapping service
  pkgs.uv          # Python package manager
  jq               # Command-line JSON processor
  quickshell        # A quick launcher for commands and scripts (like Rofi but for CLI)

  # -- Applications --
  vscode            
  google-chrome
  spotify
  discord
  qalculate-gtk
  texlive.combined.scheme-full

  # -- keyboard --
  wvkbd             # On-screen keyboard

  # -- Wallpapers & Screen Locking --
  hyprpaper         # Wallpaper utility
  hyprlock          # Screen locker

  # -- File Management --
  xfce.thunar       # File manager
  xfce.thunar-archive-plugin # Archive plugin for Thunar
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
  
  # -- Themeing --
  dracula-theme
  numix-cursor-theme
  adwaita-icon-theme
  ];

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      noto-fonts
    ];
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
