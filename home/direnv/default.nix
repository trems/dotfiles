{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

}
