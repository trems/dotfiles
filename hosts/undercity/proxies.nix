{
  config,
  lib,
  pkgs,
  ...
}: let
  locations = builtins.fromJSON (builtins.readFile ../../services/redshield-locations.json);
  vlessConfig = builtins.fromJSON (builtins.readFile ../../services/redshield-vless.json);

  undercityLocations = lib.filterAttrs (name: _: !(lib.hasPrefix "aec1d5cec4-a1b1" name)) locations;

  vlessOutbounds = lib.mapAttrsToList (name: node: {
    type = "vless";
    tag = "vless-${name}";
    server = lib.head (lib.splitString ":" node.endpoint);
    server_port = vlessConfig.server_port;
    uuid = vlessConfig.uuid;
    flow = "";
    tls = {
      enabled = true;
      server_name = vlessConfig.tls.server_name;
      utls = {
        enabled = true;
        fingerprint = vlessConfig.tls.utls.fingerprint;
      };
      reality = {
        enabled = true;
        public_key = vlessConfig.tls.reality.public_key;
        short_id = vlessConfig.tls.reality.short_id;
      };
    };
    transport = {
      type = "grpc";
      service_name = vlessConfig.transport.service_name;
    };
  }) undercityLocations;

  locationRules = lib.concatMap (name: [
    {
      auth_user = [ name ];
      rule_set = [ "geosite-ru" "geosite-gov-ru" "geosite-media-ru" "geoip-ru" ];
      outbound = "direct-out";
    }
    {
      auth_user = [ name ];
      ip_is_private = true;
      outbound = "direct-out";
    }
    {
      auth_user = [ name ];
      outbound = "vless-${name}";
    }
  ]) (builtins.attrNames undercityLocations);

  naiveUsers = lib.mapAttrsToList (name: node: {
    username = name;
    password = { _secret = config.age.secrets.subscription-uuid.path; };
  }) undercityLocations;

  directOutbound = {
    type = "direct";
    tag = "direct-out";
  };

  ruleSets = [
    {
      tag = "geosite-ru";
      type = "remote";
      format = "binary";
      url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs";
      download_detour = "direct-out";
    }
    {
      tag = "geosite-gov-ru";
      type = "remote";
      format = "binary";
      url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-gov-ru.srs";
      download_detour = "direct-out";
    }
    {
      tag = "geosite-media-ru";
      type = "remote";
      format = "binary";
      url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-media-ru.srs";
      download_detour = "direct-out";
    }
    {
      tag = "geoip-ru";
      type = "remote";
      format = "binary";
      url = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs";
      download_detour = "direct-out";
    }
  ];

  genSubScript = pkgs.writers.writePython3Bin "gen-sub" { } ''
    import json
    import base64
    import sys
    import os
    import re


    def main():
        if len(sys.argv) < 5:
            print(
                "Usage: gen-sub <locations_json> "
                "<vless_json> <uuid_file> <out_dir>"
            )
            sys.exit(1)

        locations_path = sys.argv[1]
        vless_path = sys.argv[2]
        uuid_path = sys.argv[3]
        out_dir = sys.argv[4]

        with open(locations_path, 'r') as f:
            locations = json.load(f)

        with open(vless_path, 'r') as f:
            vless_config = json.load(f)

        with open(uuid_path, 'r') as f:
            uuid_str = f.read().strip()

        os.makedirs(out_dir, exist_ok=True)

        def get_node_info(name, node):
            server_ip = node["endpoint"].split(":")[0]
            if name.startswith("aec1d5cec4-a1b1"):
                match = re.search(r"aec1d5cec4-a1b1-([0-9]+)", name)
                display_num = match.group(1) if match else "x"
                display_name = f"bypass-{display_num}"
                tls_real = vless_config["tls"]["reality"]
                trans = vless_config["transport"]
                return {
                    "is_bypass": True,
                    "display_name": display_name,
                    "server_ip": server_ip,
                    "vless_uuid": vless_config["uuid"],
                    "vless_sni": vless_config["tls"]["server_name"],
                    "vless_pbk": tls_real["public_key"],
                    "vless_sid": tls_real["short_id"],
                    "vless_service_name": trans["service_name"]
                }
            else:
                return {
                    "is_bypass": False,
                    "display_name": name,
                    "server_ip": "undercity.sharashin.ru"
                }

        # 1. Generate Shadowrocket format
        sr_lines = []
        for name in sorted(locations.keys()):
            node = locations[name]
            info = get_node_info(name, node)
            if info["is_bypass"]:
                uuid = info['vless_uuid']
                ip = info['server_ip']
                sni = info['vless_sni']
                pbk = info['vless_pbk']
                sid = info['vless_sid']
                svc = info['vless_service_name']
                disp_name = info['display_name']
                q = (
                    "encryption=none&security=reality"
                    f"&sni={sni}&pbk={pbk}&sid={sid}"
                    f"&type=grpc&serviceName={svc}"
                )
                url = f"vless://{uuid}@{ip}:443?{q}#RS-{disp_name}"
            else:
                url = (
                    f"naive+https://{name}:{uuid_str}"
                    "@undercity.sharashin.ru:443?padding=1"
                    f"#RS-{name}"
                )
            sr_lines.append(url)

        sr_content = "\n".join(sr_lines)
        sr_base64 = base64.b64encode(sr_content.encode('utf-8')).decode('utf-8')
        with open(os.path.join(out_dir, "shadowrocket.txt"), "w") as f:
            f.write(sr_base64)

        # 2. Generate Sing-box format
        sb_outbounds = []
        for name in sorted(locations.keys()):
            node = locations[name]
            info = get_node_info(name, node)
            if info["is_bypass"]:
                sb_outbounds.append({
                    "type": "vless",
                    "tag": f"RS-{info['display_name']}",
                    "server": info["server_ip"],
                    "server_port": 443,
                    "uuid": info["vless_uuid"],
                    "flow": "",
                    "tls": {
                        "enabled": True,
                        "server_name": info["vless_sni"],
                        "reality": {
                            "enabled": True,
                            "public_key": info["vless_pbk"],
                            "short_id": info["vless_sid"]
                        },
                        "utls": {
                            "enabled": True,
                            "fingerprint": "firefox"
                        }
                    },
                    "transport": {
                        "type": "grpc",
                        "service_name": info["vless_service_name"]
                    }
                })
            else:
                sb_outbounds.append({
                    "type": "naive",
                    "tag": f"RS-{name}",
                    "server": "undercity.sharashin.ru",
                    "server_port": 443,
                    "username": name,
                    "password": uuid_str,
                    "tls": {
                        "enabled": True,
                        "server_name": "undercity.sharashin.ru"
                    }
                })
        sb_config = {
            "outbounds": sb_outbounds
        }
        with open(os.path.join(out_dir, "sing-box.json"), "w") as f:
            json.dump(sb_config, f, indent=2)

        # 3. Generate Clash format
        yaml_lines = ["proxies:"]
        display_names = []
        for name in sorted(locations.keys()):
            node = locations[name]
            info = get_node_info(name, node)
            display_names.append(f"RS-{info['display_name']}")
            if info["is_bypass"]:
                svc = info['vless_service_name']
                pbk = info['vless_pbk']
                sid = info['vless_sid']
                yaml_lines.append(f"  - name: \"RS-{info['display_name']}\"")
                yaml_lines.append("    type: vless")
                yaml_lines.append(f"    server: {info['server_ip']}")
                yaml_lines.append("    port: 443")
                yaml_lines.append(f"    uuid: {info['vless_uuid']}")
                yaml_lines.append("    cipher: auto")
                yaml_lines.append("    tls: true")
                yaml_lines.append(f"    servername: {info['vless_sni']}")
                yaml_lines.append("    network: grpc")
                yaml_lines.append("    grpc-opts:")
                yaml_lines.append(f"      grpc-service-name: \"{svc}\"")
                yaml_lines.append("    reality-opts:")
                yaml_lines.append(f"      public-key: \"{pbk}\"")
                yaml_lines.append(f"      short-id: \"{sid}\"")
                yaml_lines.append("    client-fingerprint: firefox")
            else:
                yaml_lines.append(f"  - name: \"RS-{name}\"")
                yaml_lines.append("    type: http")
                yaml_lines.append("    server: undercity.sharashin.ru")
                yaml_lines.append("    port: 443")
                yaml_lines.append(f"    username: {name}")
                yaml_lines.append(f"    password: {uuid_str}")
                yaml_lines.append("    tls: true")
                yaml_lines.append("    skip-cert-verify: false")

        yaml_lines.append("\nproxy-groups:")
        yaml_lines.append("  - name: \"Red Shield\"")
        yaml_lines.append("    type: select")
        yaml_lines.append("    proxies:")
        for dn in display_names:
            yaml_lines.append(f"      - \"{dn}\"")

        with open(os.path.join(out_dir, "clash.yaml"), "w") as f:
            f.write("\n".join(yaml_lines) + "\n")

        # 4. Generate Caddyfile dynamic snippet
        caddy_lines = [
            f"route /{uuid_str} {{",
            "    @clash query flag=clash",
            "    handle @clash {",
            f"        root * {out_dir}",
            "        rewrite * /clash.yaml",
            "        file_server",
            "    }",
            "    @singbox query flag=sing-box",
            "    handle @singbox {",
            f"        root * {out_dir}",
            "        rewrite * /sing-box.json",
            "        file_server",
            "    }",
            "    handle {",
            f"        root * {out_dir}",
            "        rewrite * /shadowrocket.txt",
            "        file_server",
            "    }",
            "}"
        ]
        with open(os.path.join(out_dir, "caddy_route.conf"), "w") as f:
            f.write("\n".join(caddy_lines) + "\n")

        print("Generated subscriptions and caddy_route.conf successfully.")


    if __name__ == "__main__":
        main()
  '';
in {
  # Caddy reverse proxy for HTTPS/TLS
  services.caddy = {
    enable = true;
    virtualHosts = {
      "undercity.sharashin.ru:18443" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:8080
        '';
      };
      "undercity.sharashin.ru:443 :443" = {
        extraConfig = ''
          log {
              output stderr
          }

          route {
              import /var/lib/rsv-subscription/caddy_route.conf

              @proxy_connect method CONNECT
              reverse_proxy @proxy_connect h2c://127.0.0.1:10080 {
                  header_up Proxy-Authorization {header.Proxy-Authorization}
              }

              @proxy_auth header Proxy-Authorization *
              reverse_proxy @proxy_auth h2c://127.0.0.1:10080 {
                  header_up Proxy-Authorization {header.Proxy-Authorization}
              }

              respond "Welcome to my website" 200
          }
        '';
      };
    };
  };

  # Systemd service to generate subscription files and Caddy configuration at boot/activation
  systemd.services.rsv-subscription-gen = {
    description = "Generate Red Shield VPN subscription files";
    before = [ "caddy.service" ];
    requiredBy = [ "caddy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "gen-sub-run" ''
        mkdir -p /var/lib/rsv-subscription
        ${genSubScript}/bin/gen-sub ${../../services/redshield-locations.json} ${../../services/redshield-vless.json} ${config.age.secrets.subscription-uuid.path} /var/lib/rsv-subscription
        chown -R caddy:caddy /var/lib/rsv-subscription
        chmod -R 755 /var/lib/rsv-subscription
      '';
    };
  };

  # Host-level sing-box service
  services.sing-box = {
    enable = true;
    settings = {
      log = {
        level = "info";
      };
      dns = {
        servers = [
          {
            type = "udp";
            tag = "dns-direct";
            server = "1.1.1.1";
          }
        ];
        rules = [
          {
            rule_set = [ "geosite-ru" "geosite-gov-ru" "geosite-media-ru" ];
            server = "dns-direct";
          }
        ];
        final = "dns-direct";
      };
      inbounds = [
        {
          type = "naive";
          tag = "naive-in";
          network = "tcp";
          listen = "127.0.0.1";
          listen_port = 10080;
          users = naiveUsers;
        }
      ];
      outbounds = [
        directOutbound
      ] ++ vlessOutbounds;
      route = {
        auto_detect_interface = true;
        default_domain_resolver = "dns-direct";
        final = "direct-out";
        rules = [
          {
            protocol = "dns";
            action = "hijack-dns";
          }
        ] ++ locationRules;
        rule_set = ruleSets;
      };
    };
  };

  # Open firewall ports:
  # - 80 (Caddy ACME HTTP-01 challenge)
  # - 443 (Caddy HTTPS + NaïveProxy TCP/UDP)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ];
}
