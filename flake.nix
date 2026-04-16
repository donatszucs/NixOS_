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

    playit-nixos-module.url = "github:pedorich-n/playit-nixos-module";
  };

  outputs = inputs: {
    nixosConfigurations.doni = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        inputs.playit-nixos-module.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}