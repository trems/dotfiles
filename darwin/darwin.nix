{ pkgs, ... }:

{
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
  nix = {
    settings = { };
  };

  environment = {
    systemPackages = [
      pkgs.home-manager # all packages managed by home-manager
    ];
    # add fish to /etc/shells. Don't forget to change login shell: chsh -s /path/to/fish
    shells = [ pkgs.fish ];
  };

  programs = {
    gnupg.agent.enable = true;
    zsh = {
      enable = true; # Create /etc/zshrc that loads the nix-darwin environment.
      interactiveShellInit = ''
        alias drs="darwin-rebuild switch --flake ~/dotfiles/"
      '';
    };
    fish.enable = true;
  };

  fonts.packages = [
    pkgs.jetbrains-mono
  ];

  homebrew = {
    enable = true;
    brews = [ ];
    casks = [ ];
    taps = [ ];
    masApps = { };
  };
  services = { };
  system = {
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
      userKeyMapping = [ ]; # see https://developer.apple.com/library/content/technotes/tn2450/_index.html
    };
  };
}
