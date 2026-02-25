{ config, pkgs, ... }:

{
  # 1. User Details
  home.username = "doni";
  home.homeDirectory = "/home/doni";

  # DO NOT change this value, even when you upgrade NixOS in the future.
  # It tells Home Manager what version it was originally installed on.
  home.stateVersion = "25.11"; 

  # 2. Let Home Manager manage itself
  programs.home-manager.enable = true;

  # 3. User-specific Packages
  # Packages you put here are only installed for YOUR user, not system-wide.
  home.packages = with pkgs; [
    # Put your quickshell, hyprland utilities, etc., here
  ];

  # Cursor Theme
  home.pointerCursor = {
    name = "Numix-Cursor"; 
    package = pkgs.numix-cursor-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
  
  # 4. Theming (Your Dracula setup!)
  gtk = {
    enable = true;
    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk";
  };
}