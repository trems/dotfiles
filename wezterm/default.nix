{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}: let
  rootConfig = ''
    return require("extra.wezterm")
  '';
in {
  programs.wezterm = {
    enable = true;
    extraConfig = rootConfig;
  };

  xdg.configFile = let
    weztermLua =
      if !config.programs.wezterm.enable
      then {
        "wezterm/wezterm.lua" = {
          text = rootConfig;
        };
      }
      else {};
  in
    {
      "wezterm/extra" = {
        source = mkMutableSymlink "${dotfiles}/home/wezterm/wezterm";
      };
    }
    // weztermLua;
}
