{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.redshield-exit-nodes;

  sysctl-wrapper = pkgs.writeShellScriptBin "sysctl" ''
    echo "sysctl wrapper called with: $@" >&2
    for arg in "$@"; do
      if [[ "$arg" == *src_valid_mark=1* || "$arg" == *ip_forward=1* || "$arg" == *forwarding=1* ]]; then
        echo "sysctl wrapper: bypassing $arg" >&2
        exit 0
      fi
    done
    exec ${pkgs.procps}/bin/sysctl "$@"
  '';

  my-procps = pkgs.symlinkJoin {
    name = "procps-custom";
    paths = [ pkgs.procps ];
    postBuild = ''
      rm -f $out/bin/sysctl
      cp ${sysctl-wrapper}/bin/sysctl $out/bin/sysctl
    '';
  };

  amneziawg-tools-custom = pkgs.amneziawg-tools.override {
    procps = my-procps;
  };

  # Parameterized userspace entrypoint script
  entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
    set -e
    export PATH="${lib.makeBinPath [ pkgs.iptables pkgs.iproute2 pkgs.amneziawg-go amneziawg-tools-custom pkgs.tailscale pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.gawk sysctl-wrapper pkgs.sing-box ]}:$PATH"
    export WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go
    export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt

    # Ensure required directories exist
    mkdir -p /tmp /dev/net /var/log /var/lib/tailscale /var/lib/sing-box
    if [ ! -c /dev/net/tun ]; then
        mknod /dev/net/tun c 10 200
    fi

    RULE_SETS_CONFIG=""
    BYPASS_RU_RULES=""
    if [ "$BYPASS_RU" = "true" ]; then
        RULE_SETS_CONFIG='
  "rule_set": [
    {
      "tag": "antizapret",
      "type": "local",
      "format": "binary",
      "path": "/var/lib/sing-box/antizapret.srs"
    },
    {
      "tag": "geoip-ru",
      "type": "local",
      "format": "binary",
      "path": "/var/lib/sing-box/geoip-ru.srs"
    },
    {
      "tag": "geosite-category-ru",
      "type": "local",
      "format": "binary",
      "path": "/var/lib/sing-box/geosite-category-ru.srs"
    }
  ],'

        BYPASS_RU_RULES='
      {
        "outbound": "auto",
        "domain_suffix": [
          "chatgpt.com",
          "openai.com",
          "google.com",
          "youtube.com",
          "gemini.google.com"
        ]
      },
      {
        "outbound": "auto",
        "rule_set": [
          "antizapret"
        ]
      },
      {
        "outbound": "direct",
        "domain_suffix": [
          "kinopoisk.ru",
          "hd.kinopoisk.ru",
          "yandex.ru",
          "yandex.net",
          "vk.com",
          "gosuslugi.ru"
        ]
      },
      {
        "outbound": "direct",
        "rule_set": [
          "geosite-category-ru",
          "geoip-ru"
        ]
      },'
    fi

    # Write AmneziaWG configuration
    mkdir -p /etc/amnezia/amneziawg
    cat <<EOF > /etc/amnezia/amneziawg/awg0.conf
[Interface]
Address = $VPN_ADDRESS
PrivateKey = $VPN_PRIVATE_KEY
MTU = 1280

Jc = ''${AWG_JC:-3}
Jmin = ''${AWG_JMIN:-40}
Jmax = ''${AWG_JMAX:-70}
S1 = ''${AWG_S1:-35}
S2 = ''${AWG_S2:-89}
S3 = ''${AWG_S3:-97}
S4 = ''${AWG_S4:-20}
H1 = $AWG_H1
H2 = $AWG_H2
H3 = $AWG_H3
H4 = $AWG_H4

[Peer]
PublicKey = $VPN_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $VPN_ENDPOINT
PersistentKeepalive = 25
EOF

    # Start AmneziaWG userspace tunnel
    awg-quick up awg0

    # Apply global forwarding rules for the VPN and TUN interfaces
    iptables -A FORWARD -i awg0 -j ACCEPT
    iptables -A FORWARD -o awg0 -j ACCEPT
    iptables -A FORWARD -i singtun0 -j ACCEPT
    iptables -A FORWARD -o singtun0 -j ACCEPT

    # Setup NAT routing for bypassed subnets if enabled
    if [ "$BYPASS_RU" = "true" ]; then
        # Set up NAT masquerading for eth0 (bypassed traffic NAT)
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    fi

    # Write Sing-box configuration
    mkdir -p /etc/sing-box
    cat <<EOF > /etc/sing-box/config.json
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "singtun0",
      "address": [
        "172.18.0.1/30",
        "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "stack": "gvisor"
    }
  ],
  "outbounds": [
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": [
        "vless",
        "awg"
      ],
      "url": "http://cp.cloudflare.com/generate_204",
      "interval": "1m",
      "tolerance": 50
    },
    {
      "type": "vless",
      "tag": "vless",
      "server": "$VLESS_SERVER",
      "server_port": $VLESS_PORT,
      "uuid": "$VLESS_UUID",
      "flow": "",
      "tls": {
        "enabled": true,
        "server_name": "$VLESS_SNI",
        "utls": {
          "enabled": true,
          "fingerprint": "firefox"
        },
        "reality": {
          "enabled": true,
          "public_key": "$VLESS_PUBLIC_KEY",
          "short_id": "$VLESS_SHORT_ID"
        }
      },
      "transport": {
        "type": "grpc",
        "service_name": "$VLESS_SERVICE_NAME"
      }
    },
    {
      "type": "direct",
      "tag": "awg",
      "bind_interface": "awg0"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    $RULE_SETS_CONFIG
    "rules": [
      {
        "action": "sniff"
      },
      $BYPASS_RU_RULES
      {
        "outbound": "direct",
        "clash_mode": "direct"
      },
      {
        "outbound": "direct",
        "ip_cidr": [
          "127.0.0.1/32",
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
          "100.64.0.0/10",
          "100.100.100.100/32"
        ]
      },
      {
        "outbound": "direct",
        "ip_cidr": [
          "$VLESS_SERVER"
        ]
      }
    ],
    "auto_detect_interface": true
  }
}
EOF

    # Start Sing-box daemon
    sing-box run -c /etc/sing-box/config.json >/var/log/sing-box-run.log 2>&1 &

    # Set up normal exit-node NAT masquerading for awg0 (VPN tunnel NAT)
    iptables -t nat -A POSTROUTING -o awg0 -j MASQUERADE

    # Start Tailscaled
    mkdir -p /var/run/tailscale /var/lib/tailscale
    tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

    sleep 2

    # Connect to Tailnet
    tailscale up \
      --auth-key="$TAILSCALE_AUTH_KEY" \
      --hostname="$TAILSCALE_HOSTNAME" \
      --advertise-exit-node \
      --accept-dns=false \
      --snat-subnet-routes=false

    wait -n
  '';

  geoip-ru-srs = pkgs.fetchurl {
    url = "https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs";
    sha256 = "0w1i7h797pl2y44w9cw8wgsa92s20g6p9zx9l95n9c6mwlrq9hcb";
  };

  geosite-category-ru-srs = pkgs.fetchurl {
    url = "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-ru.srs";
    sha256 = "05zhdcasp1r9pys0cz7qii8szqipz6pg2pjsnnvwyv8i703l6jbb";
  };

  antizapret-srs = pkgs.fetchurl {
    url = "https://github.com/savely-krasovsky/antizapret-sing-box/releases/latest/download/antizapret.srs";
    sha256 = "1bkpczdhblw52x38yqxc7wq4bdn38788743qmragiyscqmdmykxd";
  };

  rulesetsDir = pkgs.runCommand "rsv-rulesets" {} ''
    mkdir -p $out/var/lib/sing-box
    ln -s ${geoip-ru-srs} $out/var/lib/sing-box/geoip-ru.srs
    ln -s ${geosite-category-ru-srs} $out/var/lib/sing-box/geosite-category-ru.srs
    ln -s ${antizapret-srs} $out/var/lib/sing-box/antizapret.srs
  '';

  # Build container image natively via Nix
  rsvImage = pkgs.dockerTools.buildImage {
    name = "rsv-exit-node";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      paths = [
        pkgs.amneziawg-go
        amneziawg-tools-custom
        pkgs.tailscale
        pkgs.iptables
        pkgs.iproute2
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.gnugrep
        pkgs.gawk
        pkgs.cacert
        sysctl-wrapper
        entrypoint
        pkgs.sing-box
        rulesetsDir
      ];
      pathsToLink = [ "/bin" "/etc" "/var/lib" ];
    };
    config = {
      Cmd = [ "/bin/entrypoint" ];
    };
  };

  locations = builtins.fromJSON (builtins.readFile ./redshield-locations.json);
  awgConfig = builtins.fromJSON (builtins.readFile ./redshield-config.json);
  vlessConfig = builtins.fromJSON (builtins.readFile ./redshield-vless.json);

  enabledNodes = genAttrs cfg.nodes (name:
    if locations ? ${name}
    then locations.${name}
    else throw "Red Shield VPN exit node location '${name}' is not defined in redshield-locations.json"
  );

  # Helper function to generate exit node container definitions
  mkExitNodeContainer = id: node: {
    image = "rsv-exit-node:latest";
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--device=/dev/net/tun:/dev/net/tun"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
      "--sysctl=net.ipv4.ip_forward=1"
      "--sysctl=net.ipv6.conf.all.forwarding=1"
      "--dns=1.1.1.1"
      "--dns=8.8.8.8"
    ];
    environmentFiles = [ "/run/rsv/env" ];
    environment = {
      TAILSCALE_HOSTNAME = node.hostname;
      VPN_ADDRESS = awgConfig.address;
      VPN_PUBLIC_KEY = awgConfig.peer_publickey;
      VPN_DNS = awgConfig.dns;
      VPN_ENDPOINT = node.endpoint;
      BYPASS_RU = if node.bypassRu then "true" else "false";
      AWG_JC = awgConfig.jc;
      AWG_JMIN = awgConfig.jmin;
      AWG_JMAX = awgConfig.jmax;
      AWG_S1 = awgConfig.s1;
      AWG_S2 = awgConfig.s2;
      AWG_S3 = awgConfig.s3;
      AWG_S4 = awgConfig.s4;
      AWG_H1 = awgConfig.h1;
      AWG_H2 = awgConfig.h2;
      AWG_H3 = awgConfig.h3;
      AWG_H4 = awgConfig.h4;
      VLESS_SERVER = head (splitString ":" node.endpoint);
      VLESS_PORT = toString vlessConfig.server_port;
      VLESS_UUID = vlessConfig.uuid;
      VLESS_SNI = vlessConfig.tls.server_name;
      VLESS_PUBLIC_KEY = vlessConfig.tls.reality.public_key;
      VLESS_SHORT_ID = vlessConfig.tls.reality.short_id;
      VLESS_SERVICE_NAME = vlessConfig.transport.service_name;
    };
    volumes = [
      "/var/lib/rsv-multitun/${id}:/var/lib/tailscale"
    ];
  };

in {
  options.services.redshield-exit-nodes = {
    enable = mkEnableOption "Red Shield VPN Multiplexing Exit Nodes";
    
    tailscaleAuthKeyPath = mkOption {
      type = types.path;
      description = "Path to tailscale auth key secret file";
    };

    redshieldPrivateKeyPath = mkOption {
      type = types.path;
      description = "Path to Red Shield VPN private key secret";
    };

    nodes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of exit node location names to enable (e.g. [ \"latvia\" \"kazakhstan\" \"france\" ])";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # Systemd service to prep combined environment file before containers start
    systemd.services = let
      routingNodes = filter (node: node != "russia" && node != "belarus" && node != "kazakhstan") cfg.nodes;
    in {
      rsv-prep-env = {
        description = "Prepare Environment File for Red Shield VPN containers";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /run/rsv
          TS_KEY=$(cat ${cfg.tailscaleAuthKeyPath})
          RS_KEY=$(cat ${cfg.redshieldPrivateKeyPath})
          echo "TAILSCALE_AUTH_KEY=$TS_KEY" > /run/rsv/env
          echo "VPN_PRIVATE_KEY=$RS_KEY" >> /run/rsv/env
          chmod 600 /run/rsv/env
        '';
      };

      rsv-load-image = {
        description = "Load Red Shield VPN Docker Image";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.docker}/bin/docker load -i ${rsvImage}
        '';
      };

      rsv-host-route = {
        description = "Route Tailscale Controlplane through a working Red Shield VPN container";
        after = [ "docker.service" ] ++ (map (id: "docker-rsv-${id}.service") cfg.nodes);
        wants = map (id: "docker-rsv-${id}.service") cfg.nodes;
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          CONTAINER_IP=""
          for id in ${concatStringsSep " " routingNodes}; do
            if ${pkgs.docker}/bin/docker inspect -f '{{.State.Running}}' rsv-$id 2>/dev/null | grep -q "true"; then
              IP=$(${pkgs.docker}/bin/docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' rsv-$id 2>/dev/null)
              if [ -n "$IP" ]; then
                CONTAINER_IP="$IP"
                echo "Selected container rsv-$id with IP $CONTAINER_IP for routing"
                break
              fi
            fi
          done

          if [ -n "$CONTAINER_IP" ]; then
            echo "Adding route for Tailscale controlplane (192.200.0.0/21) via $CONTAINER_IP"
            ${pkgs.iproute2}/bin/ip route replace 192.200.0.0/21 via "$CONTAINER_IP"
          else
            echo "Error: No running non-blocked Red Shield VPN container found to route Tailscale traffic!" >&2
            exit 1
          fi
        '';
        preStop = ''
          echo "Removing Tailscale controlplane route"
          ${pkgs.iproute2}/bin/ip route del 192.200.0.0/21 2>/dev/null || true
        '';
      };
    } // (genAttrs (map (id: "docker-rsv-${id}") cfg.nodes) (serviceName: {
      after = [ "rsv-prep-env.service" "rsv-load-image.service" ];
      wants = [ "rsv-prep-env.service" "rsv-load-image.service" ];
    }));

    virtualisation.oci-containers = {
      backend = "docker";
      containers = mapAttrs' (id: node: nameValuePair "rsv-${id}" (mkExitNodeContainer id node)) enabledNodes;
    };
  };
}
