{
  description = "Quickflow - Desktop Environment Shell & Peripheral Suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: pkgs:
        let
          peripheral-monitor = pkgs.rustPlatform.buildRustPackage {
            pname = "peripherial_monitor";
            version = "0.1.0";
            src = ./scripts/peripherial_monitor;
            cargoLock = {
              lockFile = ./scripts/peripherial_monitor/Cargo.lock;
            };
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.udev ];
          };

          runtimeDeps = with pkgs; [
            # Quickflow peripheral daemon
            peripheral-monitor

            # Audio & Volume
            wireplumber     # wpctl
            pipewire        # pw-play
            pwvucontrol     # volume control GUI

            # Display & Brightness
            ddcutil         # monitor brightness via DDC/CI
            wlsunset        # night light / gamma temperature

            # Wayland & Desktop Tools
            hyprland        # hyprctl
            hyprpaper       # wallpaper daemon
            wl-clipboard    # wl-copy
            cliphist        # clipboard manager
            wtype           # virtual keystrokes (passwords / auto-paste)
            wvkbd           # wvkbd-mobintl virtual keyboard

            # Connectivity & Secrets
            bluez           # bluetoothctl
            networkmanager  # nm-connection-editor
            overskride      # bluetooth manager GUI
            rbw             # Bitwarden CLI

            # Scripts & Utilities
            nodejs          # scripts/fetch_calendar.js
            jq              # json querying
            libnotify       # notify-send
            procps          # top, free, pkill
            coreutils       # cat, sleep, printf, echo, mkdir, ln
            gawk            # awk
            findutils       # find, xargs
            bash
          ];

          quickflux-wrapped = pkgs.symlinkJoin {
            name = "quickflux";
            paths = [ pkgs.quickshell ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/quickshell \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
                --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.qtimageformats}/${pkgs.qt6.qtbase.qtPluginPrefix}"
              ln -s $out/bin/quickshell $out/bin/quickflux
            '';
          };

          # Standalone runner that runs local directory if present, otherwise default config
          quickflux-runner = pkgs.writeShellScriptBin "quickflux-runner" ''
            if [ $# -gt 0 ]; then
              exec ${quickflux-wrapped}/bin/quickshell "$@"
            elif [ -f "./shell.qml" ]; then
              exec ${quickflux-wrapped}/bin/quickshell --path .
            else
              exec ${quickflux-wrapped}/bin/quickshell
            fi
          '';

          # Immutable store package with QML assets bundled
          quickflux-bundle = pkgs.stdenv.mkDerivation {
            pname = "quickflux-bundle";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/share/quickflux
              cp -r . $out/share/quickflux/

              mkdir -p $out/bin
              makeWrapper ${quickflux-wrapped}/bin/quickshell $out/bin/quickflux-desktop \
                --add-flags "--path $out/share/quickflux"
            '';
          };
        in
        {
          default = quickflux-wrapped;
          quickflux = quickflux-wrapped;
          quickshell = quickflux-wrapped; # backward compatibility alias
          quickflux-runner = quickflux-runner;
          quickflux-bundle = quickflux-bundle;
          peripheral-monitor = peripheral-monitor;
        }
      );

      apps = forAllSystems (system: pkgs:
        let
          pkgs_system = self.packages.${system};
        in
        {
          default = {
            type = "app";
            program = "${pkgs_system.quickflux-runner}/bin/quickflux-runner";
            meta.description = "Launch Quickflow desktop shell";
          };
          quickflux = {
            type = "app";
            program = "${pkgs_system.quickflux}/bin/quickflux";
            meta.description = "Run wrapped Quickflow binary";
          };
          quickshell = {
            type = "app";
            program = "${pkgs_system.quickshell}/bin/quickshell";
            meta.description = "Run wrapped Quickshell binary";
          };
          peripheral-monitor = {
            type = "app";
            program = "${pkgs_system.peripheral-monitor}/bin/peripherial_monitor";
            meta.description = "Run Keychron M6 & Tapo light monitor daemon";
          };
        }
      );

      devShells = forAllSystems (system: pkgs:
        let
          pkgs_system = self.packages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [ pkgs.pkg-config pkgs.makeWrapper ];
            buildInputs = with pkgs; [
              cargo
              rustc
              udev
              nodejs
              pkgs_system.quickflux
            ];
          };
        }
      );

      # NixOS system module for consuming in NixOS configurations
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          qfPkg = self.packages.${system}.quickflux;
          pmPkg = self.packages.${system}.peripheral-monitor;
        in
        {
          environment.systemPackages = [
            qfPkg
            pmPkg
          ];

          # Keychron M6 mouse udev access
          services.udev.extraRules = ''
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="d030", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="d03f", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
          '';

          # User service for peripheral battery and Tapo light monitor
          systemd.user.services.peripheral-monitor = {
            description = "Keychron M6 & Tapo Peripheral Monitor Daemon";
            wantedBy = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${pmPkg}/bin/peripherial_monitor";
              EnvironmentFile = "-%h/.config/peripheral-monitor/tapo.env";
              Restart = "always";
              RestartSec = 3;
            };
          };
        };

      nixosModules.quickflux = self.nixosModules.default;

      # Home Manager module for standalone user environment management
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          qfPkg = self.packages.${system}.quickflux;
          pmPkg = self.packages.${system}.peripheral-monitor;
        in
        {
          home.packages = [
            qfPkg
            pmPkg
          ];

          systemd.user.services.peripheral-monitor = {
            Unit = {
              Description = "Keychron M6 & Tapo Peripheral Monitor Daemon";
              After = [ "graphical-session.target" ];
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pmPkg}/bin/peripherial_monitor";
              EnvironmentFile = "-%h/.config/peripheral-monitor/tapo.env";
              Restart = "always";
              RestartSec = 3;
            };
          };
        };

      homeManagerModules.quickflux = self.homeManagerModules.default;
    };
}
