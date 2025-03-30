{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };
}
