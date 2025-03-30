{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return require("extra.wezterm")
    '';
  };

  xdg.configFile."wezterm/extra" = {
    source = mkMutableSymlink "${dotfiles}/home/wezterm/wezterm";
  };

}
