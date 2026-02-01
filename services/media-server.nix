{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.my-media-server;
in {
  options.services.my-media-server = {
    enable = lib.mkEnableOption "Home Media Server Stack";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Основной пользователь системы, который будет иметь полные права на файлы";
    };

    sharePath = lib.mkOption {
      type = lib.types.path;
      default = "/srv/share";
      description = "Путь к корневой директории файлопомойки";
    };
    torrentHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 3030;
      description = "Порт для веб-интерфейса торрент-клиента";
    };

    filebrowserHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 3031;
      description = "Порт для веб-интерфейса файлового браузера";
    };
  };

  config = lib.mkIf cfg.enable {
    # --- 1. Группы и Права ---
    users.groups.media = {};

    # Добавляем пользователей в группу media
    users.users.${cfg.user}.extraGroups = ["media"];
    users.users.${config.services.rqbit.user}.extraGroups = ["media"];
    users.users.${config.services.jellyfin.user}.extraGroups = ["media"];
    users.users.${config.services.filebrowser.user}.extraGroups = ["media"];

    # Создаем структуру папок через systemd-tmpfiles
    # d = directory, 0775 = rwxrwxr-x (группа может писать), root:media = владелец
    systemd.tmpfiles.rules = [
      "d ${cfg.sharePath} 0775 root media -"
      "d ${cfg.sharePath}/downloads 0775 rqbit media -"
      "d ${cfg.sharePath}/video 0775 root media -"
      "d ${cfg.sharePath}/documents 0775 root media -"
    ];

    # --- 2. Торрент-клиент (rqbit) ---
    services.rqbit = {
      enable = true;
      peerPort = 4240;
      httpPort = cfg.torrentHttpPort;
      httpHost = "0.0.0.0";
      openFirewall = true;
      downloadDir = "${cfg.sharePath}/downloads";
    };
    # Маска 0002 означает, что новые файлы будут создаваться с правами 775/664 (группа может писать)
    # systemd.services.rqbit.serviceConfig.UMask = lib.mkForce "0002";

    # --- 3. Медиа-сервер (Jellyfin) ---
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    # --- 4. SMB (Samba) ---
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "NixOS NAS";
          "netbios name" = "nixos-nas";
          "security" = "user";
          "map to guest" = "Bad User";
        };
        "public" = {
          "path" = cfg.sharePath; # Используем переменную
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0664";
          "directory mask" = "0775";
          "force group" = "media";
        };
      };
    };

    # Сетевое обнаружение Windows
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    # Сетевое обнаружение Apple/Linux (mDNS)
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    # --- 5. Файловый менеджер (FileBrowser) ---
    services.filebrowser = {
      enable = true;
      openFirewall = true;
      settings = {
        address = "0.0.0.0";
        port = cfg.filebrowserHttpPort;
        root = cfg.sharePath; # Используем переменную
        # username = "admin";
        # password = "admin";
        noauth = true;
      };
    };
    # Добавляем хаки для прав доступа
    # systemd.services.filebrowser.serviceConfig.SupplementaryGroups = ["media"];
    # systemd.services.filebrowser.serviceConfig.UMask = "0002";
  };
}
