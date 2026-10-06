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
          mouse-monitor = pkgs.rustPlatform.buildRustPackage {
            pname = "mouse_monitor";
            version = "0.1.0";
            src = ./scripts/peripherial_monitor;
            cargoLock = {
              lockFile = ./scripts/peripherial_monitor/Cargo.lock;
            };
            cargoBuildFlags = [ "-p" "mouse_monitor" ];
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.udev ];
          };

          light-controller = pkgs.rustPlatform.buildRustPackage {
            pname = "light_controller";
            version = "0.1.0";
            src = ./scripts/peripherial_monitor;
            cargoLock = {
              lockFile = ./scripts/peripherial_monitor/Cargo.lock;
            };
            cargoBuildFlags = [ "-p" "light_controller" ];
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.udev ];
          };

          phone-monitor = pkgs.rustPlatform.buildRustPackage {
            pname = "phone_monitor";
            version = "0.1.0";
            src = ./scripts/peripherial_monitor;
            cargoLock = {
              lockFile = ./scripts/peripherial_monitor/Cargo.lock;
            };
            cargoBuildFlags = [ "-p" "phone_monitor" ];
          };

          runtimeDeps = with pkgs; [
            # Quickflow peripheral daemons
            mouse-monitor
            light-controller
            phone-monitor

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
          mouse-monitor = mouse-monitor;
          light-controller = light-controller;
          peripheral-monitor = mouse-monitor; # backward compatibility alias
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
          mouse-monitor = {
            type = "app";
            program = "${pkgs_system.mouse-monitor}/bin/mouse_monitor";
            meta.description = "Run Keychron mouse battery monitor daemon";
          };
          light-controller = {
            type = "app";
            program = "${pkgs_system.light-controller}/bin/light_controller";
            meta.description = "Run Tapo light controller daemon";
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
              quickshell
            ];
          };
        }
      );

      # NixOS system module for consuming in NixOS configurations
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          qfPkg = self.packages.${system}.quickflux;
          mmPkg = self.packages.${system}.mouse-monitor;
          lcPkg = self.packages.${system}.light-controller;
        in
        {
          environment.systemPackages = [
            qfPkg
            mmPkg
            lcPkg
          ];

          # Keychron mouse and wireless receiver udev access (M6, M6S 8K, Ultra-Link 0x3434:0xd028, etc.)
          services.udev.extraRules = ''
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess"
          '';

          systemd.user.services.mouse-monitor = {
            description = "Keychron Mouse Battery Monitor";
            wantedBy = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${mmPkg}/bin/mouse_monitor";
              Restart = "always";
              RestartSec = 3;
            };
          };

          systemd.user.services.light-controller = {
            description = "Tapo Light Controller";
            wantedBy = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${lcPkg}/bin/light_controller";
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
          mmPkg = self.packages.${system}.mouse-monitor;
          lcPkg = self.packages.${system}.light-controller;
        in
        {
          home.packages = [
            qfPkg
            mmPkg
            lcPkg
          ];

          systemd.user.services.mouse-monitor = {
            Unit = {
              Description = "Keychron Mouse Battery Monitor";
              After = [ "graphical-session.target" ];
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${mmPkg}/bin/mouse_monitor";
              Restart = "always";
              RestartSec = 3;
            };
          };

          systemd.user.services.light-controller = {
            Unit = {
              Description = "Tapo Light Controller";
              After = [ "graphical-session.target" ];
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${lcPkg}/bin/light_controller";
              EnvironmentFile = "-%h/.config/peripheral-monitor/tapo.env";
              Restart = "always";
              RestartSec = 3;
            };
          };
        };

      homeManagerModules.quickflux = self.homeManagerModules.default;
    };
}
