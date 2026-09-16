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

          quickflow-wrapped = pkgs.symlinkJoin {
            name = "quickflow";
            paths = [ pkgs.quickshell ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/quickshell \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
                --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.qtimageformats}/${pkgs.qt6.qtbase.qtPluginPrefix}"
              ln -s $out/bin/quickshell $out/bin/quickflow
            '';
          };

          # Standalone runner that runs local directory if present, otherwise default config
          quickflow-runner = pkgs.writeShellScriptBin "quickflow-runner" ''
            if [ $# -gt 0 ]; then
              exec ${quickflow-wrapped}/bin/quickshell "$@"
            elif [ -f "./shell.qml" ]; then
              exec ${quickflow-wrapped}/bin/quickshell --path .
            else
              exec ${quickflow-wrapped}/bin/quickshell
            fi
          '';

          # Immutable store package with QML assets bundled
          quickflow-bundle = pkgs.stdenv.mkDerivation {
            pname = "quickflow-bundle";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/share/quickflow
              cp -r . $out/share/quickflow/

              mkdir -p $out/bin
              makeWrapper ${quickflow-wrapped}/bin/quickshell $out/bin/quickflow-desktop \
                --add-flags "--path $out/share/quickflow"
            '';
          };
        in
        {
          default = quickflow-wrapped;
          quickflow = quickflow-wrapped;
          quickshell = quickflow-wrapped; # backward compatibility alias
          quickflow-runner = quickflow-runner;
          quickflow-bundle = quickflow-bundle;
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
            program = "${pkgs_system.quickflow-runner}/bin/quickflow-runner";
            meta.description = "Launch Quickflow desktop shell";
          };
          quickflow = {
            type = "app";
            program = "${pkgs_system.quickflow}/bin/quickflow";
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
              pkgs_system.quickflow
            ];
          };
        }
      );

      # NixOS system module for consuming in NixOS configurations
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          qfPkg = self.packages.${system}.quickflow;
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

      nixosModules.quickflow = self.nixosModules.default;

      # Home Manager module for standalone user environment management
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          qfPkg = self.packages.${system}.quickflow;
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

      homeManagerModules.quickflow = self.homeManagerModules.default;
    };
}
