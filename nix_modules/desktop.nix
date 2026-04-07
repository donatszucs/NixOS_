{ config, pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal pkgs.xdg-desktop-portal-gtk ];
  };

  # Enable Hyprland
  programs.hyprland.enable = true;

  # Enable dconf for application settings
  programs.dconf.enable = true;

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

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.caskaydia-mono
      noto-fonts
    ];

    fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "CaskaydiaMono NFP" ];
      sansSerif = [ "CaskaydiaMono NFP" ];
      serif = [ "CaskaydiaMono NFP" ];
    };
    localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <match target="pattern">
          <test name="family" compare="eq">
            <string>CaskaydiaMono NFP</string>
          </test>
          <edit name="weight" mode="assign">
            <const>demibold</const>
          </edit>
        </match>
      </fontconfig>
    '';
    };
  };

  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            # Explicitly tell keyd to keep capslock normal by default
            capslock = "capslock";
          };
          meta = {
            # When Super (meta) is held, make it F13
            capslock = "f13";
          };
        };
      };
    };
  };
}
