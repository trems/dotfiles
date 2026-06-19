{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
  nix = {
    settings = {
      trusted-users = [ "root" user ];
    };
    buildMachines = [
      {
        hostName = "192.168.0.102"; # home-laptop2 IP (or use "home-laptop2" if Tailscale MagicDNS is enabled)
        sshUser = "mike";
        sshKey = "/Users/${user}/.ssh/id_ed25519";
        systems = [ "x86_64-linux" "aarch64-linux" ];
        maxJobs = 4;
        speedFactor = 1;
        supportedFeatures = [ "kvm" "benchmark" "nixos-test" "big-parallel" ];
      }
    ];
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };

  environment = {
    systemPackages = with pkgs; [
      home-manager # all packages managed by home-manager
      python3
    ];
    # add fish to /etc/shells. Don't forget to change login shell: chsh -s /path/to/fish
    shells = [pkgs.fish];
    interactiveShellInit = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    # Declarative Nix custom config for Determinate Nix remote building
    etc."nix/nix.custom.conf".text = ''
      # Managed by nix-darwin in dotfiles
      builders = ssh://mike@192.168.0.102 x86_64-linux /Users/${user}/.ssh/id_ed25519 4 1 kvm,benchmark,nixos-test - -
      builders-use-substitutes = true
      trusted-users = root ${user}
    '';
  };

  programs = {
    gnupg.agent.enable = true;
    ssh.knownHosts = {
      home-laptop2 = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIteJxePAOsUTL2ZANy1jXwzhbt/UepwU1U+Iq/1pkj1";
        extraHostNames = [ "192.168.0.102" "home-laptop2" ];
      };
    };
    zsh = {
      enable = true; # Create /etc/zshrc that loads the nix-darwin environment.
      interactiveShellInit = ''
        alias drs="sudo darwin-rebuild switch --flake ~/dotfiles/"
      '';
    };
    fish = {
      enable = true; # required for login shell
      interactiveShellInit = ''
        alias drs="sudo darwin-rebuild switch --flake ~/dotfiles/"
      '';
    };
  };

  fonts.packages = [
    pkgs.jetbrains-mono
  ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
    };
    brews = [
      "qwen-code" # unstable nixpkgs contains old version
      "opencode"
      "pi-coding-agent"
    ];
    casks = [
      "brave-browser"
      "orbstack"
      "codex"
      "antigravity"
      "antigravity-cli"
      "karabiner-elements"
      "handy"
    ];
    taps = [];
    masApps = {};
  };

  services = {
    openssh.enable = true;
  };

  system = {
    primaryUser = user;
    defaults = {
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        AppleShowAllExtensions = true;
        AppleKeyboardUIMode = 3;
        NSDocumentSaveNewDocumentsToCloud = false;
      };
      dock = {
        autohide = true;
        orientation = "right";
      };
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf"; # limit default search scope to current folder
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv"; # “icnv” = Icon view, “Nlsv” = List view, “clmv” = Column View, “Flwv” = Gallery View
        NewWindowTarget = "Home";
        ShowMountedServersOnDesktop = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
      };
      screencapture = {
        target = "clipboard";
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
      userKeyMapping = [ ]; # see https://developer.apple.com/library/content/technotes/tn2450/_index.html
    };
  };
}
