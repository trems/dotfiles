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
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-laptop2"; # должно совпадать с именем в flake!
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Yekaterinburg";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    wget
    neovim
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    openssh.authorizedKeys.keys = [
      publicKeys.ucb-mbp
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLeUpRLdLM9bNaZ2utFfHtw4MPIlj3vo6UjW2aFE9eA msharashin@IT-MAC-NB165.local"
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
    blocky = {
      enable = true;
      settings = {
        ports = {
          dns = 53;
          http = 4000; # TODO: open port
        };
        upstreams.groups.default = [
          "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
        ];
        # For initially solving DoH/DoT Requests when no system Resolver is available.
        bootstrapDns = {
          # upstream = "https://one.one.one.one/dns-query";
          upstream = "https://dns.cloudflare.com/dns-query";
          ips = ["1.1.1.1" "1.0.0.1"];
        };
        #Enable blocking of certain domains.
        blocking = {
          blackLists = {
            #Adblocking
            ads = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"
              "https://blocklistproject.github.io/Lists/ads.txt"
              "https://github.com/Zalexanninev15/NoADS_RU/raw/refs/heads/main/hosts/blockerFL.txt"
            ];
            #Another filter for blocking adult sites
            adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
            #You can add additional categories
            # bypass = ["https://raw.githubusercontent.com/Zalexanninev15/NoADS_RU/refs/heads/main/hosts/bypass.txt"];
          };
          #Configure what block categories are used
          clientGroupsBlock = {
            default = ["ads" "bypass"];
            kids-ipad = ["ads" "adult"];
          };
        };
        prometheus = {
          enable = true;
          path = "/metrics";
        };
      };
    };
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
