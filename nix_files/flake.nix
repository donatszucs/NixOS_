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

    quickflow = {
      url = "path:../dotfiles/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        default = inputs.quickflow.packages.${system}.default;
        quickflow = inputs.quickflow.packages.${system}.quickflow;
        peripheral-monitor = inputs.quickflow.packages.${system}.peripheral-monitor;
      };

      nixosConfigurations.doni = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          inputs.playit-nixos-module.nixosModules.default
          inputs.quickflow.nixosModules.default
          ./configuration.nix
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
