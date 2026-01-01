{
  self,
  config,
  lib,
  pkgs,
  publicKeys,
  ...
}: let
  user = "mike";
in {
  imports = [
    ./hardware-configuration.nix
    ../../services/blocky.nix
    ../../services/monitoring
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "home-laptop2"; # должно совпадать с именем в flake!
    networkmanager.enable = true;
  };

  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    wget
    neovim
    btop
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    openssh.authorizedKeys.keys = [
      publicKeys.ucb-mbp
    ];

    packages = with pkgs; [
      tree
    ];
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
      };
    };
    logind.settings.Login.HandleLidSwitch = "ignore";
    tailscale.enable = true;
  };

  security.sudo.extraRules = [
    {
      users = [user];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  system.stateVersion = "25.05"; # Did you read the comment?
}
