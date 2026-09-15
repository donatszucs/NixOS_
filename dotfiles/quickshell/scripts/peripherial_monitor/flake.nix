{
  description = "Keychron M6 & Tapo Peripheral Monitor Daemon";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      peripheral-monitor = pkgs.rustPlatform.buildRustPackage {
        pname = "peripherial_monitor";
        version = "0.1.0";
        src = ./.;
        cargoLock = {
          lockFile = ./Cargo.lock;
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

      apps.${system}.default = {
        type = "app";
        program = "${peripheral-monitor}/bin/peripherial_monitor";
      };

      devShells.${system}.default = pkgs.mkShell {
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [
          cargo
          rustc
          udev
        ];
      };
    };
}
