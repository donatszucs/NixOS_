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

    # Make Qt apps use GTK integration to inherit the GTK dark theme
    QT_QPA_PLATFORMTHEME = "gtk3";

    QSG_RHI_BACKEND = "vulkan";
    MOZ_ENABLE_WAYLAND = "1";

    NIXOS_OZONE_WL = "1";
  };

  # Ensure GTK apps (and browsers) report dark mode
  # Force GTK theme in the environment and write GTK settings files
  home.sessionVariables.GTK_THEME = "catppuccin-mocha-mauve-standard+normal:dark";
  # Cursor Theme
  home.pointerCursor = {
    enable = true;
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
      name = "catppuccin-mocha-mauve-standard+normal";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        size = "standard";
        tweaks = [ "normal" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.theme = null;
    gtk4.extraCss = ''
      @define-color accent_color #cba6f7;
      @define-color accent_bg_color #cba6f7;
      @define-color accent_fg_color #1e1e2e;
      @define-color window_bg_color #1e1e2e;
      @define-color window_fg_color #cdd6f4;
      @define-color view_bg_color #181825;
      @define-color view_fg_color #cdd6f4;
      @define-color headerbar_bg_color #181825;
      @define-color headerbar_fg_color #cdd6f4;
      @define-color card_bg_color #1e1e2e;
      @define-color card_fg_color #cdd6f4;
      @define-color popover_bg_color #181825;
      @define-color popover_fg_color #cdd6f4;
      @define-color sidebar_bg_color #181825;
      @define-color sidebar_fg_color #cdd6f4;
      @define-color dialog_bg_color #1e1e2e;
      @define-color dialog_fg_color #cdd6f4;
      @define-color warning_color #f9e2af;
      @define-color error_color #f38ba8;
      @define-color success_color #a6e3a1;
      @define-color destructive_color #f38ba8;
    '';
  };

  # Also set the FreeDesktop/GNOME color-scheme portal preference
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # Write KDE config for the dark color scheme, which Qt/KDE apps (incl. KDE Connect) check for
  home.file.".config/kdeglobals".text = ''
    [General]
    ColorScheme=BreezeDark

    [KDE]
    LookAndFeelPackage=org.kde.breezedark.desktop
    widgetStyle=BreezeDark
    SingleClick=false

    [Icons]
    Theme=Dracula
  '';

  # kdedefaults/kdeglobals is read by KDE apps as a system-level override layer.
  # Without this, KDE Connect (and other KDE apps) ignore kdeglobals and fall back
  # to the stale BreezeLight entry that KDE Plasma wrote here previously.
  home.file.".config/kdedefaults/kdeglobals".text = ''
    [General]
    ColorScheme=BreezeDark

    [KDE]
    LookAndFeelPackage=org.kde.breezedark.desktop
    widgetStyle=BreezeDark

    [Icons]
    Theme=Dracula
  '';

  home.file.".config/xsettingsd/xsettingsd.conf".text = ''
    Net/ThemeName "catppuccin-mocha-mauve-standard+normal"
    Net/IconThemeName "Dracula"
    Gtk/CursorThemeName "Bibata-Modern-Ice"
    Gtk/CursorThemeSize 24
    Net/EnableEventSounds 1
    EnableInputFeedbackSounds 0
    Xft/Antialias 1
    Xft/Hinting 1
    Xft/HintStyle "hintslight"
    Xft/RGBA "rgb"
  '';
}
