{ config, pkgs, lib, ... }:

let
  # 1. Собираем ассеты используя инструменты Mac (buildPackages),
  # так как файлы .dat одинаковы для всех архитектур.
  daeAssets = pkgs.buildPackages.symlinkJoin {
    name = "dae-assets";
    paths = [
      pkgs.buildPackages.v2ray-geoip
      pkgs.buildPackages.v2ray-domain-list-community
    ];
  };

  # 2. Шаблон конфига
  daeConfigTemplate = pkgs.writeText "dae-template.dae" ''
    global {
      wan_interface: auto
      log_level: info
      tproxy_port: 12345
      tproxy_port_protect: true
      so_mark_from_dae: 0x80000000
    }
    node {
      my_hy2: '$HYSTERIA_LINK'
    }
    group {
      proxy {
        policy: min
      }
    }
    dns {
      upstream {
        googledns: 'tcp+udp://8.8.8.8:53'
        cfdns: 'tcp+udp://1.1.1.1:53'
      }
      routing {
        request {
          qname(geosite:CATEGORY-RU) -> googledns
          fallback: googledns
        }
      }
    }
    routing {
      pname(NetworkManager, systemd-resolved, dhcpcd) -> direct
      dip(224.0.0.0/4, 255.255.255.255/32) -> direct
      dip(89.110.65.104) -> direct
      dip(geoip:private) -> direct
      dip(geoip:ru) -> direct
      domain(geosite:CATEGORY-RU) -> direct
      domain(geosite:tailscale) -> direct
      domain(keyword: yandex, keyword: vk, keyword: gosuslugi) -> direct
      fallback: proxy
    }
  '';

in
{
  # Включаем форвардинг
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # Секрет с конфигом клиента Hysteria
  age.secrets.hysteria-client-conf = {
    name = "hy2-client.yaml";
    file = ../secrets/hy2-client.yaml.age;
  };

  # Устанавливаем пакет dae в систему
  environment.systemPackages = [ pkgs.dae ];

  # ВАЖНО: Не используем services.dae.enable = true, чтобы избежать бага в модуле.
  # Вместо этого определяем сервис вручную.
  systemd.services.dae = {
    description = "dae: Linux high-performance transparent proxy solution";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "systemd-sysctl.service" ];
    wants = [ "network-online.target" ];

    # Передаем путь к нашим "Mac-built" ассетам
    environment.DAE_LOCATION_ASSET = "${daeAssets}/share/v2ray";

    serviceConfig = {
      # Ограничиваем права (как в официальном модуле)
      LimitNPROC = 512;
      LimitNOFILE = 1048576;
      # CapabilityBoundingSet может потребоваться настроить, если будут проблемы с правами,
      # но обычно dae требует root или CAP_NET_ADMIN.
      # Для простоты запускаем от root (стандартное поведение).
      ExecStart = "${lib.getExe pkgs.dae} run --disable-timestamp -c /run/dae/config.dae";
      ExecReload = "${lib.getExe pkgs.dae} reload -c /run/dae/config.dae";
      Restart = "on-abort";
    };

    # Скрипт подготовки (генерация конфига)
    preStart = ''
      mkdir -p /run/dae
      
      # Генерируем ссылку
      LINK=$(${lib.getExe pkgs.hysteria} share -c ${config.age.secrets.hysteria-client-conf.path})
      export HYSTERIA_LINK="$LINK"
      
      # Подставляем в шаблон
      ${lib.getExe pkgs.envsubst} < ${daeConfigTemplate} > /run/dae/config.dae
      chmod 600 /run/dae/config.dae
      
      # Валидация конфига перед запуском
      ${lib.getExe pkgs.dae} validate -c /run/dae/config.dae
    '';
  };
}
