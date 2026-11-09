{
  mkMutableSymlink,
  dotfiles,
  ...
}: {
  # пофайлово: в ~/.config/opencode лежат рантайм-файлы (cli.json, node_modules), которые трекать нельзя
  xdg.configFile."opencode/opencode.json".source = mkMutableSymlink "${dotfiles}/home/opencode/opencode.json";
  xdg.configFile."opencode/tui.json".source = mkMutableSymlink "${dotfiles}/home/opencode/tui.json";
  xdg.configFile."opencode/themes/tokyonight-herdr.json".source =
    mkMutableSymlink "${dotfiles}/home/opencode/themes/tokyonight-herdr.json";
}
