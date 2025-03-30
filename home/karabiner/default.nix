{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  xdg.configFile."karabiner".source = mkMutableSymlink "${dotfiles}/home/karabiner/karabiner";
}
