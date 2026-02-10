Installation:

git clone https://github.com/donatszucs/NixOS_.git ~/nixos-config

cd ~/nixos-config

chmod +x setup.sh && ./setup.sh

sudo nixos-rebuild switch

Notes:

SuperMouse preset needs to be added in Input Remapper

Tapo light setup:

    - uv init, add tapo/python-dotenv

    - .env in the scripts folder with the variables
