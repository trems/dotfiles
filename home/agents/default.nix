{
  config,
  pkgs,
  lib,
  mkMutableSymlink,
  dotfiles,
  ...
}: let
  # свои глобальные скиллы: папка в ./skills — это скилл, новый подхватывается без правок nix
  skills = builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./skills));
  # ~/.agents — Codex, pi, opencode; ~/.claude — Claude Code, opencode; ~/.gemini/config — agy
  linkSkill = name: let
    src = mkMutableSymlink "${dotfiles}/home/agents/skills/${name}";
  in {
    ".agents/skills/${name}".source = src;
    ".claude/skills/${name}".source = src;
    ".gemini/config/skills/${name}".source = src;
  };

  # Linux здесь только корпоративный Lenovo: он выходит из RU, и OpenAI/Anthropic отвечают 403.
  # Агенты ходят через sing-box на home-laptop2 (services/sing-box.nix), остальной трафик не трогаем.
  proxy = "http://home-laptop2.sharashin.mesh:1081";
  proxied = bin: pkg:
    pkgs.writeShellScriptBin bin ''
      export HTTPS_PROXY=${proxy} HTTP_PROXY=${proxy}
      export NO_PROXY=localhost,127.0.0.1,.wb.ru,.wildberries.ru,.sharashin.mesh
      exec ${lib.getExe pkg} "$@"
    '';
in {
  home.file =
    lib.mergeAttrsList (map linkSkill skills)
    // {
      # общий для macOS и Linux: пути в нём только через $HOME
      ".claude/settings.json".source = mkMutableSymlink "${dotfiles}/home/agents/claude/settings.json";
      ".gemini/antigravity-cli/settings.json".source = mkMutableSymlink "${dotfiles}/home/agents/agy/settings.json";
      ".gemini/antigravity-cli/keybindings.json".source = mkMutableSymlink "${dotfiles}/home/agents/agy/keybindings.json";
    };

  # путь явный и одинаковый на обеих машинах: opencode.json читает его через {file:~/...},
  # а дефолтный ($XDG_RUNTIME_DIR / DARWIN_USER_TEMP_DIR) в {file:} не раскрывается
  age.secrets.tns-ai-key = {
    file = ../../secrets/wb/tns-ai-key.age;
    path = "${config.home.homeDirectory}/.local/share/agenix/tns-ai-key";
  };

  # на macOS агенты ставятся из brew (darwin/default.nix)
  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    (proxied "claude" pkgs.claude-code)
    (proxied "opencode" pkgs.opencode)
    (proxied "agy" pkgs.antigravity-cli)
  ];
}
