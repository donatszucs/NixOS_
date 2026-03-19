{ config, pkgs, ... }:

{
  boot.kernelParams = [
    "nvidia.NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable I2C kernel modules
  hardware.i2c.enable = true;

  # Enable GVFS for file management in Thunar and other GTK apps
  services.gvfs.enable = true;

  # 1. Enable firmware (Critical for WiFi/Bluetooth)
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # 2. Bluetooth Settings
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true; # Show battery charge for supported devices
        JustWorksRepairing = "always"; # Helps with some devices that fail to pair
      };
    };
  };

  # 3. Force load the kernel module (Driver)
  boot.kernelModules = [ "btusb" ];

  # Enable the graphics driver
  hardware.graphics.enable = true;

  # Load the Nvidia driver
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is usually required for Hyprland
    modesetting.enable = true;

    # Set this to true for RTX 2000 series or newer.
    open = true;

    # Nvidia power management.
    powerManagement.enable = true;
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
    pulse.enable = true; # This lets you use PulseAudio tools!
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

  # udev rule for HyperX Cloud II Wireless 0x03f0:0x018b
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="018b", MODE="0666"
  '';
}
