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
        path = "${dotfiles}";
        uri = "git@github.com:trems/dotfiles.git";
        interval = 4000;
      };
    };
  };

  # без этого флага git-sync отказывается синхронизировать ветку
  programs.git.includes = [
    {
      condition = "gitdir:${dotfiles}/";
      contents.git-sync.syncEnabled = true;
    }
  ];
}
