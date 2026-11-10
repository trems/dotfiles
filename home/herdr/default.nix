{
  config,
  lib,
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

    "herdr-core/templates".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-core/templates";

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

    "herdr-app/layouts/custom.json".source =
      mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/layouts/custom.json";
  }
  # Свои моды (over9k): по папке, т.к. в herdr-app/mods лежат и встроенные моды,
  # которые Herdr синхронизирует сам. Herdr 0.1.14 не грузит SVG-иконки мода
  # через симлинк (исправлено в herdr-app#427, ещё не в релизе).
  // lib.genAttrs' [
    "over9k"
    "over9k-close"
    "over9k-handoff"
    "over9k-menu"
    "over9k-new-menu"
    "over9k-options"
    "over9k-panel"
    "over9k-rename"
    "over9k-server-stop"
    "over9k-switcher"
  ] (name:
    lib.nameValuePair "herdr-app/mods/${name}" {
      source = mkMutableSymlink "${dotfiles}/home/herdr/herdr-app/mods/${name}";
    });
}
