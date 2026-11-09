{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}: {
  # herdr-core предоставляет бинарник 'hc' и рантайм для терминалов / Herdr.app
  # legacy herdr TUI (programs.herdr / pkgs.herdr) удален
  home.packages = [
    pkgs.herdr-core
  ];

  # Изменяемые конфигурации через out-of-store симлинки на репозиторий dotfiles
  xdg.configFile = {
    # herdr-core (hc)
    "herdr-core/config.toml".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-core/config.toml";

    # herdr-app (GUI): симлинкуем только пользовательские файлы настроек и темы,
    # чтобы runtime-файлы (сокеты, кэш, состояние сессии) не загрязняли git.
    "herdr-app/settings.json".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/settings.json";

    "herdr-app/keys.json".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/keys.json";

    "herdr-app/themes/tokyonight-moon.json".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/themes/tokyonight-moon.json";

    "herdr-app/themes/tokyonight.json".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/themes/tokyonight.json";
  };
}
