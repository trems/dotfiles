{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

}
