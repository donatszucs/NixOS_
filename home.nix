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

  home.sessionVariables = {
      HYPRCURSOR_THEME = "Bibata-Modern-Ice";
      HYPRCURSOR_SIZE = 24;

      # Not used on Hyprland, HYPRCURSOR values takes precedence
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = 24;
    };
  # Cursor Theme
  home.pointerCursor = {
      name = "Bibata-Modern-Ice"; 
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      hyprcursor.enable = true;
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
    platformTheme.name = "kde";
    style = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
  };
}