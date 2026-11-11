{
  config,
  pkgs,
  lib,
  dotfiles,
  ...
}: let
  # pull-only: коммиты и push — руками; merge --ff-only сам откажется,
  # если ветка разошлась или локальные правки пересекаются с входящими.
  # ssh берётся системный из PATH: nix-овый не видит SSSD-пользователей на Lenovo
  pull = pkgs.writeShellScript "dotfiles-pull" ''
    cd ${dotfiles} && ${pkgs.git}/bin/git fetch -q origin && ${pkgs.git}/bin/git merge -q --ff-only '@{u}'
  '';
in {
  launchd.agents.dotfiles-pull = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = ["${pull}"];
      StartInterval = 600;
      RunAtLoad = true;
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/dotfiles-pull.log";
    };
  };

  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.dotfiles-pull = {
      Unit.Description = "Pull dotfiles (fast-forward only)";
      Service = {
        Type = "oneshot";
        ExecStart = "${pull}";
      };
    };
    timers.dotfiles-pull = {
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = "10min";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
