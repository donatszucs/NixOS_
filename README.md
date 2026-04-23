Installation:

git clone https://github.com/donatszucs/NixOS_.git ~/nixos-config

cd ~/nixos-config

chmod +x setup.sh && ./setup.sh

sudo nixos-rebuild switch

Notes:

SuperMouse preset needs to be added in Input Remapper

delete old builds:
    - **sudo nix-collect-garbage --delete-older-than 5d**
list generations:
    - **sudo nixos-rebuild list-generations**

Python scripts setup:

    - In scripts folder: uv init scriptsEnv
