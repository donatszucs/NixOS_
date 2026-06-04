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

      # Make Qt apps use KDE integration and prefer Breeze style
      QT_QPA_PLATFORMTHEME = "kde";
      QT_STYLE_OVERRIDE = "Dracula";

      # Help apps detect a KDE-like desktop for choosing dark variant
      XDG_CURRENT_DESKTOP = "KDE";
      KDE_FULL_SESSION = "true";

      QSG_RHI_BACKEND = "vulkan";
      MOZ_ENABLE_WAYLAND = "1";

      NIXOS_OZONE_WL = "1";
    };

  # Ensure GTK apps (and browsers) report dark mode
  # Force GTK theme in the environment and write GTK settings files
  home.sessionVariables.GTK_THEME = "Dracula";
  # Cursor Theme
  home.pointerCursor = {
      name = "Bibata-Modern-Ice"; 
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      hyprcursor.enable = true;
  };
  
  # 4. Theming
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
    gtk4.theme = null;
  };

  # Also set the FreeDesktop/GNOME color-scheme portal preference
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style = {
      name = "Dracula";
    };
  };

  # Write a minimal KDE config for the dark color scheme, which some Qt apps check for
  home.file.".config/kdeglobals".text = ''
  [General]
  ColorScheme=Dracula
  '';
}