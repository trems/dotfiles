{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  programs.lazygit = {
    enable = true;
  };

  xdg.configFile."lazygit".source = mkMutableSymlink "${dotfiles}/home/lazygit/lazygit";

}
