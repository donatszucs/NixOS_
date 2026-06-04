{ config, pkgs, ... }:

{
  # Prevent the Minecraft server from starting automatically on boot
  systemd.services.minecraft-server.wantedBy = pkgs.lib.mkForce [ ];

  # to start run mc-sv start

  # ==========================================
  # 1. MINECRAFT SERVER CONFIGURATION
  # ==========================================
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    
    serverProperties = {
      motd = "Szia Eszter, Csenge, Donat!";
      "initial-enabled-gamerules" = "playersSleepingPercentage=1";
      level-name = "ECD-World";
      difficulty = "normal";
      gamemode = "survival";
      max-players = 20;
      white-list = false; # Anyone with the IP can join
      
      # RCON Setup for admin commands
      enable-rcon = true;
      "rcon.password" = "asd123asd321"; 
      "rcon.port" = 25575;
    };
  };
  services.playit = {
    enable = true;
    # Tell it exactly where we safely hid the file earlier
    secretPath = "/etc/playit/playit.toml"; 
  };
}