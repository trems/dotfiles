{
  config,
  pkgs,
  ...
}: {
  programs.herdr = {
    enable = true;
  };

  # herdr-core предоставляет бинарник 'hc', необходимый для GUI (Herdr.app)
  home.packages = [
    pkgs.herdr-core
  ];
}
