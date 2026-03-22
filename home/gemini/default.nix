{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  ${config.home.homeDirectory}.".gemini".source = mkMutableSymlink "${dotfiles}/home/gemini/config";
}
