{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  services.git-sync = {
    enable = true;
    repositories = {
      dotfiles = {
        path = dotfiles;
        uri = "git@github.com:trems/dotfiles.git";
        interval = 4000;
      };
    };
  };

}
