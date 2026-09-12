{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    playit-nixos-module = {
      url = "github:pedorich-n/playit-nixos-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      peripheral-monitor = pkgs.rustPlatform.buildRustPackage {
        pname = "peripherial_monitor";
        version = "0.1.0";
        src = ./rust_daemons/peripherial_monitor;
        cargoLock = {
          lockFile = ./rust_daemons/peripherial_monitor/Cargo.lock;
        };
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.udev ];
      };
    in
    {
      packages.${system} = {
        default = peripheral-monitor;
        peripheral-monitor = peripheral-monitor;
      };

      nixosConfigurations.doni = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          inputs.playit-nixos-module.nixosModules.default
          ./configuration.nix
          {
            environment.systemPackages = [ peripheral-monitor ];
            systemd.user.services.peripheral-monitor = {
              description = "Keychron M6 Peripheral Monitor Daemon";
              wantedBy = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              serviceConfig = {
                ExecStart = "${peripheral-monitor}/bin/peripherial_monitor";
                Restart = "always";
                RestartSec = 3;
              };
            };
          }
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo
          rustc
          gcc
          pkg-config
          systemd
        ];
      };
    };
}
