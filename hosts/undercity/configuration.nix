{
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
    ./disko.nix
    ./headscale.nix
    ./proxies.nix
  ];

  # Use GRUB bootloader with dual EFI + legacy BIOS support
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "/dev/vda";
  };

  networking = {
    hostName = "undercity";
    # Automatically obtain IP address on all interfaces
    useDHCP = lib.mkDefault true;
  };

  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    wget
    neovim
    btop
  ];

  # Define agenix secrets
  age.secrets = {
    subscription-uuid.file = ../../secrets/subscription-uuid.age;
  };

  # Define the primary user account
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    openssh.authorizedKeys.keys = with publicKeys; [ macbook-air-m1 mbp ];
  };

  # Authorize keys for the root user as well
  users.users.root.openssh.authorizedKeys.keys = with publicKeys; [ macbook-air-m1 mbp ];

  # SSH service configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password"; # Allows nixos-anywhere/deploy-rs root access
    };
  };

  # Sudo rules - allow mike to run commands without password
  security.sudo.extraRules = [
    {
      users = [ user ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Swapfile (4GB) to guard against out-of-memory states
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  system.stateVersion = "25.05";
}
