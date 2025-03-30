{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  programs.k9s = {
    enable = true;
  };
}
