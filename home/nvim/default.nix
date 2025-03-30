{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."nvim" = {
    source = mkMutableSymlink "${dotfiles}/home/nvim/nvim";
  };

}
