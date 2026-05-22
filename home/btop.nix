{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  programs.btop = {
    enable = true;
  };

}
