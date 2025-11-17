{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-laptop2"; # должно совпадать с именем в flake!
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLeUpRLdLM9bNaZ2utFfHtw4MPIlj3vo6UjW2aFE9eA msharashin@IT-MAC-NB165.local"
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
    # logind.lidSwitch = "ignore";
    logind.settings.Login.HandleLidSwitch = "ignore";
  };

  security.sudo.extraRules = [
    {
      users = ["mike"]; # ← замените на ваше имя пользователя
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
