{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

}
