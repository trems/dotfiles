{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  programs.fd = {
    enable = true;
    hidden = true;
    ignores = [
      ".git/"
      "vendor/"
    ];
  };

}
