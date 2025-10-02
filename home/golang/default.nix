{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:
{
  programs.go = {
    enable = true;
    env = {
      GOPRIVATE = "git.ucb.local";
    };
  };
}
