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
        Privacy = "off"; # "device" causes address rotation which drops modern Xbox BLE controllers
        FastConnectable = true;
        JustWorksRepairing = "always"; # Ensures clean reconnects without pairing handshake failures
      };
      LE = {
        MinConnectionInterval = 7;
        MaxConnectionInterval = 9;
        ConnectionLatency = 0;
        ConnectionSupervisionTimeout = 320; # 3.2s timeout prevents drops during RF packet bursts/rumble
      };
    };
  };

  # NOTE: Do NOT disable ERTM on modern Linux kernels (6.x/7.x) with BLE Xbox controllers!
  # Kakra (xpadneo lead developer) notes that ERTM should remain enabled.
  # Disabling ERTM is an obsolete workaround from Linux 4.x and causes connection instability.
  boot.extraModprobeConfig = ''
    options hid_xpadneo ff_connect_notify=0
  '';

  hardware.xpadneo.enable = true;
  hardware.uinput.enable = true; # For virtual inputs (e.g. Sunshine)

  # 3. Force load the kernel module (Driver)
  boot.kernelModules = [
    "btusb"
    "ntsync"
    "usbmon"
  ];

  # Enable the graphics driver and OpenCL runtimes
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      pocl # CPU OpenCL implementation (Option 1 fallback)
    ];
  };

  # Expose OpenCL ICD directory at /etc/OpenCL/vendors for standard tools
  systemd.tmpfiles.rules = [
    "L+ /etc/OpenCL/vendors - - - - /run/opengl-driver/etc/OpenCL/vendors"
  ];

  # Load the Nvidia driver
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting is usually required for Hyprland
    modesetting.enable = true;

    # Set this to true for RTX 2000 series or newer.
    open = true;

    # Nvidia power management.
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # Ensure you are using the latest driver
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Docker and NVIDIA Container Toolkit (for GPU passthrough in Docker)
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
  hardware.nvidia-container-toolkit = {
    enable = true;
    mounts = [
      {
        hostPath = "/run/opengl-driver/etc/OpenCL/vendors";
        containerPath = "/etc/OpenCL/vendors";
      }
    ];
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false; # Disable the old backend
  security.rtkit.enable = true; # Recommended for audio scheduling
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # This lets you use PulseAudio tools!
    extraConfig.pipewire."92-high-quality" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [
          44100
          48000
          88200
          96000
        ];
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 2048;
      };
    };
  };
  # Enable Bluetooth audio support
  services.blueman.enable = true;

  # udev rules for HyperX headsets, Keychron mice (0x3434), wireshark usbmon, and ASUS BT500 dongle
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="018b", MODE="0666"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="02cc", MODE="0666"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="01cc", MODE="0666"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="190e", TEST=="power/control", ATTR{power/control}="on"
  '';
}
