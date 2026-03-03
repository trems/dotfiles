{
  config,
  pkgs,
  ...
}: let
  transparentProxyPort = 12345;
  gatewayInterface = "wlp1s0";
  localNet = "192.168.0.0/24";
  routerIp = "192.168.0.1";
  serverIp = "192.168.0.102";
  tailscaleV4 = "100.64.0.0/10";
  socksProxyPort = 1080;
  socksDirectPort = 1081;
  socksTransparentCompatPort = 1082;
in {
  age.secrets.hys2-password.file = ../secrets/hys2/auth.age;
  age.secrets.hys2-server.file = ../secrets/hys2/server.age;
  age.secrets.hys2-obfs-pass.file = ../secrets/hys2/obfs-pass.age;

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.wlp1s0.rp_filter" = 0;
    "net.ipv4.conf.wlp1s0.proxy_arp" = 1;
  };

  networking.firewall = {
    allowedTCPPorts = [socksDirectPort socksProxyPort socksTransparentCompatPort transparentProxyPort];
    allowedUDPPorts = [socksDirectPort socksProxyPort socksTransparentCompatPort transparentProxyPort];
    extraCommands = ''
      set -e

      ip_cmd='${pkgs.iproute2}/bin/ip'
      iptables_cmd='${pkgs.iptables}/bin/iptables'

      ipt() {
        "$iptables_cmd" -w 5 "$@"
      }

      # Cleanup legacy TPROXY rules (from previous revisions) to avoid rule conflicts.
      ipt -t mangle -D PREROUTING -j SINGBOX_TPROXY 2>/dev/null || true
      ipt -t mangle -F SINGBOX_TPROXY 2>/dev/null || true
      ipt -t mangle -X SINGBOX_TPROXY 2>/dev/null || true
      "$ip_cmd" -4 rule del fwmark 1 lookup 100 priority 100 2>/dev/null || true
      "$ip_cmd" -4 route flush table 100 2>/dev/null || true

      # Transparent TCP interception via NAT REDIRECT (more stable than TPROXY on some hosts)
      ipt -t nat -N SINGBOX_REDIRECT 2>/dev/null || true
      ipt -t nat -F SINGBOX_REDIRECT
      ipt -t nat -D PREROUTING -j SINGBOX_REDIRECT 2>/dev/null || true
      ipt -t nat -A PREROUTING -j SINGBOX_REDIRECT

      # Bypass local/router/tailscale traffic
      ipt -t nat -A SINGBOX_REDIRECT -s ${serverIp} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -d ${serverIp} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -s ${routerIp} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -d ${routerIp} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -s ${localNet} -d ${localNet} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -s ${tailscaleV4} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -d ${tailscaleV4} -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -i tailscale0 -j RETURN
      ipt -t nat -A SINGBOX_REDIRECT -p tcp --sport ${toString transparentProxyPort} -j RETURN

      # Intercept LAN TCP traffic and redirect to sing-box redirect inbound
      ipt -t nat -A SINGBOX_REDIRECT -s ${localNet} -p tcp -j REDIRECT --to-ports ${toString transparentProxyPort}

      # Allow routed traffic through this host
      ipt -D FORWARD -s ${localNet} -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -d ${localNet} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -i tailscale0 -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -o tailscale0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      ipt -A FORWARD -s ${localNet} -j ACCEPT
      ipt -A FORWARD -d ${localNet} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      ipt -A FORWARD -i tailscale0 -j ACCEPT
      ipt -A FORWARD -o tailscale0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

      # NAT clients behind this gateway (important when router and clients share same L2)
      ipt -t nat -D POSTROUTING -s ${localNet} -o ${gatewayInterface} -j MASQUERADE 2>/dev/null || true
      ipt -t nat -A POSTROUTING -s ${localNet} -o ${gatewayInterface} -j MASQUERADE
    '';
    extraStopCommands = ''
      set +e

      ip_cmd='${pkgs.iproute2}/bin/ip'
      iptables_cmd='${pkgs.iptables}/bin/iptables'

      ipt() {
        "$iptables_cmd" -w 5 "$@"
      }

      ipt -t nat -D PREROUTING -j SINGBOX_REDIRECT 2>/dev/null || true
      ipt -t nat -F SINGBOX_REDIRECT 2>/dev/null || true
      ipt -t nat -X SINGBOX_REDIRECT 2>/dev/null || true

      ipt -D FORWARD -s ${localNet} -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -d ${localNet} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -i tailscale0 -j ACCEPT 2>/dev/null || true
      ipt -D FORWARD -o tailscale0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      ipt -t nat -D POSTROUTING -s ${localNet} -o ${gatewayInterface} -j MASQUERADE 2>/dev/null || true

      # Also cleanup legacy TPROXY leftovers.
      ipt -t mangle -D PREROUTING -j SINGBOX_TPROXY 2>/dev/null || true
      ipt -t mangle -F SINGBOX_TPROXY 2>/dev/null || true
      ipt -t mangle -X SINGBOX_TPROXY 2>/dev/null || true
      "$ip_cmd" -4 rule del fwmark 1 lookup 100 priority 100 2>/dev/null || true
      "$ip_cmd" -4 route flush table 100 2>/dev/null || true
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
        # Redirect inbound for transparent TCP proxying from gateway clients
        {
          type = "redirect";
          tag = "tproxy-in";
          listen = "0.0.0.0";
          listen_port = transparentProxyPort;
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
        # Fallback for clients that cannot use transparent proxying:
        # SOCKS inbound with the same route handling as tproxy-in.
        {
          type = "socks";
          tag = "socks-tproxy-compat";
          listen = "::";
          listen_port = socksTransparentCompatPort;
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
          {
            inbound = "tproxy-in";
            action = "sniff";
            timeout = "300ms";
          }
          {
            inbound = "socks-tproxy-compat";
            action = "sniff";
            timeout = "300ms";
          }
          {
            protocol = "dns";
            action = "hijack-dns";
          }
          {
            rule_set = "geosite-ads";
            action = "reject";
          }
          {
            inbound = "socks-force-proxy";
            outbound = "proxy-out";
          }
          {
            inbound = "socks-force-direct";
            outbound = "direct-out";
          }
          {
            rule_set = "geosite-ru";
            outbound = "direct-out";
          }
          {
            rule_set = "geosite-gov-ru";
            outbound = "direct-out";
          }
          {
            rule_set = "geosite-media-ru";
            outbound = "direct-out";
          }
          {
            rule_set = "geoip-ru";
            outbound = "direct-out";
          }
          {
            inbound = "tproxy-in";
            outbound = "proxy-out";
          }
          {
            inbound = "socks-tproxy-compat";
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
