# all options https://nix-community.github.io/home-manager/options.xhtml
{
  config,
  pkgs,
  lib,
  ...
}:
let
  mkMutableSymlink = config.lib.file.mkOutOfStoreSymlink;
  dotfiles = "${config.home.homeDirectory}/dotfiles";
in
{
  _module.args = { inherit mkMutableSymlink dotfiles; };
  home = {
    stateVersion = "25.05";
    sessionPath = [ ]; # Extra directories to prepend to PATH, e.g. "$HOME/.local/bin" or "\${xdg.configHome}/emacs/bin"
    sessionVariables = { }; # environment variables

    packages = with pkgs; [
      micro
      grpcurl
      s3cmd
      imagemagick
      tokei
      postgresql
      hysteria

      go-task
      gnumake
      # cargo

      nixd
      nil
      gopls

      nixfmt-rfc-style
      golangci-lint

      go
      rustup
      nodejs_24

      aider-chat
    ];
  };
  xdg.enable = true;

  imports = [
    ./git
    # ./ssh
    ./wezterm
    ./nvim
    ./fish
    ./lazygit
    ./zoxide
    ./bat
    ./ripgrep
    ./fzf
    ./fd
    ./eza
    ./k9s
    ./kube
    ./direnv
    ./karabiner

    #services
    ./git-sync
    ./syncthing
  ];

  targets.darwin = {
    linkApps.enable = true;
  };
}
