{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  home.packages = with pkgs; [
    neovim
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  xdg.configFile."nvim" = {
    source = mkMutableSymlink "${dotfiles}/home/nvim/nvim";
  };

}
