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
  ];

  # Use GRUB bootloader with dual EFI + legacy BIOS support
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "/dev/vda";
  };

  networking = {
    hostName = "ironforge";
    useDHCP = false;
    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "89.110.65.104";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = "89.110.65.1";
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";

  services.dbus.implementation = "dbus";

  environment.systemPackages = with pkgs; [
    git
    wget
    neovim
    btop
    curl
  ];

  # Define the primary user account
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = with publicKeys; [ macbook-air-m1 mbp home-laptop2 ];
  };

  # Authorize keys for the root user as well
  users.users.root.openssh.authorizedKeys.keys = with publicKeys; [ macbook-air-m1 mbp home-laptop2 ];

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

  # Optimization for 1GB RAM / 10GB HDD:
  # 1. Compressed swap in RAM
  zramSwap.enable = true;

  # 2. Swapfile (1.5GB) as a fallback against OOM
  swapDevices = [
    {
      device = "/swapfile";
      size = 1536;
    }
  ];

  # 3. Disable documentation to save build time and disk space
  documentation.enable = false;
  documentation.nixos.enable = false;

  # 4. Automatic garbage collection and store optimization
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings.auto-optimise-store = true;

  # Age secrets
  age.secrets = {
    tailscale-ironforge-auth-key.file = ../../secrets/tailscale-ironforge-auth-key.age;
  };

  # Tailscale configuration connected to Headscale as an exit node
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-ironforge-auth-key.path;
    extraUpFlags = [
      "--login-server=https://undercity.sharashin.ru:18443"
      "--advertise-exit-node"
      "--hostname=ironforge"
      "--accept-dns=false"
      "--snat-subnet-routes=true"
    ];
    useRoutingFeatures = "both";
    openFirewall = true;
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
  };

  system.stateVersion = "25.05";
}
