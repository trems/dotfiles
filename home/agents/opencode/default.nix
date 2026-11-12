{
  mkMutableSymlink,
  dotfiles,
  ...
}: {
  # пофайлово: в ~/.config/opencode лежат рантайм-файлы (service.json, node_modules), которые трекать нельзя
  xdg.configFile."opencode/opencode.json".source = mkMutableSymlink "${dotfiles}/home/agents/opencode/opencode.json";
  # v2 держит тему и UI в cli.json (tui.json — v1, мигрирован в него)
  xdg.configFile."opencode/cli.json".source = mkMutableSymlink "${dotfiles}/home/agents/opencode/cli.json";
  xdg.configFile."opencode/themes/tokyonight-herdr.json".source =
    mkMutableSymlink "${dotfiles}/home/agents/opencode/themes/tokyonight-herdr.json";
}
