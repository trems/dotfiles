{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}: {
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    git = false;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
      "--total-size"
    ];
  };
}
