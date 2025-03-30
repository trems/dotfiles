{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      pager = "less --RAW-CONTROL-CHARS --quit-if-one-screen --mouse";
      italic-text = "always";
    };
  };

}
