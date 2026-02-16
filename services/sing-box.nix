{
  config,
  pkgs,
  ...
}: let
  tproxyPort = 12345;
  socksProxyPort = 1080;
  socksDirectPort = 1081;
in {
  age.secrets.hys2-password.file = ../secrets/hys2/auth.age;
  age.secrets.hys2-server.file = ../secrets/hys2/server.age;
  age.secrets.hys2-obfs-pass.file = ../secrets/hys2/obfs-pass.age;

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv4.conf.all.rp_filter" = 0;
  };

  networking.firewall = {
    allowedTCPPorts = [socksDirectPort socksProxyPort tproxyPort];
    allowedUDPPorts = [socksDirectPort socksProxyPort tproxyPort];
    # extraCommands = ''
    #   set -e
    #
    #   # Конфигурация
    #   INTERFACE="wlp1s0"
    #   PROXY_PORT="12345"
    #   LOCAL_NET="192.168.0.0/24"
    #   ROUTER_IP="192.168.0.1"
    #   SERVER_IP="192.168.0.102"
    #   TAILSCALE_V4="100.64.0.0/10"
    #
    #   echo "Настройка TProxy с исключением Tailscale..."
    #
    #   # 1. Системные параметры
    #   sysctl -w net.ipv4.ip_forward=1 >/dev/null
    #   sysctl -w net.ipv4.conf."$INTERFACE".proxy_arp=1 >/dev/null
    #   sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
    #   sysctl -w net.ipv4.conf."$INTERFACE".rp_filter=0 >/dev/null
    #
    #   # 2. Очистка правил
    #   iptables -t mangle -F 2>/dev/null || true
    #   iptables -t mangle -X 2>/dev/null || true
    #   iptables -t nat -F 2>/dev/null || true
    #   ip rule del fwmark 1 table 100 2>/dev/null || true
    #   ip route flush table 100 2>/dev/null || true
    #
    #   # 3. Таблица маршрутизации
    #   ip route add local 0.0.0.0/0 dev lo table 100 2>/dev/null || true
    #   ip rule add fwmark 1 lookup 100 priority 100 2>/dev/null || true
    #
    #   # 4. Исключения — ВСЁ, что НЕ должно идти через прокси (порядок критичен!)
    #
    #   # 4a. Исключаем трафик самого сервера
    #   iptables -t mangle -A PREROUTING -s "$SERVER_IP" -j RETURN
    #   iptables -t mangle -A PREROUTING -d "$SERVER_IP" -j RETURN
    #
    #   # 4b. Исключаем роутер (сервер сам выходит в интернет через него)
    #   iptables -t mangle -A PREROUTING -s "$ROUTER_IP" -j RETURN
    #   iptables -t mangle -A PREROUTING -d "$ROUTER_IP" -j RETURN
    #
    #   # 4c. Исключаем локальный трафик (устройства внутри сети)
    #   iptables -t mangle -A PREROUTING -s "$LOCAL_NET" -d "$LOCAL_NET" -j RETURN
    #
    #   # 4d. Исключаем весь Tailscale-трафик
    #   iptables -t mangle -A PREROUTING -s "$TAILSCALE_V4" -j RETURN
    #   iptables -t mangle -A PREROUTING -d "$TAILSCALE_V4" -j RETURN
    #   iptables -t mangle -A PREROUTING -i tailscale0 -j RETURN
    #
    #   # 4e. Исключаем ответы от sing-box (предотвращаем зацикливание)
    #   iptables -t mangle -A PREROUTING -p tcp --sport "$PROXY_PORT" -j RETURN
    #   iptables -t mangle -A PREROUTING -p udp --sport "$PROXY_PORT" -j RETURN
    #
    #   # 5. Помечаем ТОЛЬКО внешний трафик от клиентов локальной сети
    #   #    (все исключения выше уже отработали через RETURN)
    #   iptables -t mangle -A PREROUTING -s "$LOCAL_NET" -j MARK --set-mark 1
    #
    #   # 6. Перенаправляем помеченный трафик в sing-box
    #   iptables -t mangle -A PREROUTING -p tcp -m mark --mark 1 -j TPROXY \
    #     --tproxy-mark 0x1/0x1 --on-port "$PROXY_PORT" --on-ip 0.0.0.0
    #   iptables -t mangle -A PREROUTING -p udp -m mark --mark 1 -j TPROXY \
    #     --tproxy-mark 0x1/0x1 --on-port "$PROXY_PORT" --on-ip 0.0.0.0
    #
    #   # 7. Маскарадинг для клиентов
    #   # iptables -t nat -A POSTROUTING -o "$INTERFACE" -s "$LOCAL_NET" -j MASQUERADE
    #   iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE
    #
    #   # 8. Маршрут по умолчанию — через роутер
    #   ip route replace default via "$ROUTER_IP" dev "$INTERFACE" 2>/dev/null || true
    #
    #   echo "✓ TProxy настроен успешно"
    #   echo "  • Клиенты: шлюз $SERVER_IP"
    #   echo "  • Сервер:  шлюз $ROUTER_IP"
    #   echo "  • Tailscale полностью исключён"
    #   echo ""
    #   echo "Правила mangle/PREROUTING:"
    #   iptables -t mangle -L PREROUTING -n -v --line-numbers
    # '';
    extraStopCommands = ''
    '';
  };

  services.sing-box = {
    enable = true;
    settings = {
      log.level = "info";

      dns = {
        servers = [
          {
            type = "https";
            tag = "dns-remote";
            server = "dns.google";
            path = "/dns-query";
            domain_resolver = "dns-direct";
          }
          {
            type = "udp";
            tag = "dns-direct";
            server = "1.1.1.1";
          }
        ];
        rules = [
          # Новая логика DNS через rule_set
          {
            rule_set = "geosite-ads";
            action = "predefined";
            rcode = "REFUSED";
          }
          {
            rule_set = "geosite-ru";
            server = "dns-direct";
          }
          # Default rule for all other queries
          {
            server = "dns-remote";
          }
        ];
        final = "dns-remote";
      };

      inbounds = [
        # TPROXY для прозрачного проксирования трафика, проходящего через сервер
        {
          type = "tproxy";
          tag = "tproxy-in";
          listen = "0.0.0.0";
          listen_port = tproxyPort;
        }
        # Вход для браузера: "Принудительный прокси"
        {
          type = "socks";
          tag = "socks-force-proxy";
          listen = "::";
          listen_port = socksProxyPort;
        }
        # Вход для браузера: "Принудительный Direct"
        {
          type = "socks";
          tag = "socks-force-direct";
          listen = "::";
          listen_port = socksDirectPort;
        }
      ];

      outbounds = [
        {
          type = "hysteria2";
          tag = "proxy-out";
          server = {_secret = config.age.secrets.hys2-server.path;};
          server_port = 1443;
          password = {_secret = config.age.secrets.hys2-password.path;};
          obfs = {
            type = "salamander";
            password = {_secret = config.age.secrets.hys2-obfs-pass.path;};
          };
          tls = {
            enabled = true;
            server_name = {_secret = config.age.secrets.hys2-server.path;};
          };
          domain_resolver = "dns-remote"; # Resolve domains through the remote DNS server
        }
        {
          type = "direct";
          tag = "direct-out";
        }
      ];

      route = {
        auto_detect_interface = true;
        default_domain_resolver = "dns-remote"; # Default resolver for outbounds without explicit domain_resolver
        final = "proxy-out";
        rules = [
          # Обработка помеченного трафика от других устройств
          # {
          #   port = [${toString tproxyPort}];
          #   action = "resolve";
          # }
          {
            inbound = "tproxy-in";
            action = "sniff";
            timeout = "300ms";
          }
          {
            protocol = "dns";
            action = "hijack-dns";
          }
          # {
          #   rule_set = "geosite-ads";
          #   action = "reject";
          # }
          {
            inbound = "socks-force-proxy";
            outbound = "proxy-out";
          }
          {
            inbound = "socks-force-direct";
            outbound = "direct-out";
          }
          # {
          #   rule_set = "geosite-ru";
          #   outbound = "direct-out";
          # }
          # {
          #   rule_set = "geosite-gov-ru";
          #   outbound = "direct-out";
          # }
          # {
          #   rule_set = "geosite-media-ru";
          #   outbound = "direct-out";
          # }
          # {
          #   rule_set = "geoip-ru";
          #   outbound = "direct-out";
          # }
          {
            inbound = "tproxy-in";
            outbound = "proxy-out";
          }
          {
            ip_is_private = true;
            outbound = "direct-out";
          }
          # {
          #   protocol = "bittorrent";
          #   outbound = "direct-out";
          # }
        ];
        rule_set = [
          {
            tag = "geosite-ru";
            type = "remote";
            format = "binary";
            url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs";
            download_detour = "proxy-out"; # Качаем через прокси, если GitHub заблокирован
          }
          {
            tag = "geosite-gov-ru";
            type = "remote";
            format = "binary";
            url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-gov-ru.srs";
            download_detour = "proxy-out";
          }
          {
            tag = "geosite-media-ru";
            type = "remote";
            format = "binary";
            url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-media-ru.srs";
            download_detour = "proxy-out";
          }
          {
            tag = "geoip-ru";
            type = "remote";
            format = "binary";
            url = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs";
            download_detour = "proxy-out";
          }
          {
            tag = "geosite-ads";
            type = "remote";
            format = "binary";
            url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs";
            download_detour = "proxy-out";
          }
        ];
      };

      experimental = {
        cache_file = {
          enabled = true;
          path = "/var/lib/sing-box/cache.db";
        };
      };
    };
  };
}
