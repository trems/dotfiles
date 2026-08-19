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

    # Keep the Headscale control plane reachable when the host Tailscale
    # client is disabled. The VPN policy route is installed below, so pin
    # the control-plane hostname to its public address before that happens.
    grep -q 'undercity.sharashin.ru' /etc/hosts || \
      echo '192.144.12.164 undercity.sharashin.ru' >> /etc/hosts

    ETH0_GW=$(ip route show default dev eth0 2>/dev/null | awk '{print $3}' | head -n1)
    if [ -n "$ETH0_GW" ]; then
        ip route replace 192.144.12.164 via "$ETH0_GW" dev eth0
    fi

    RULE_SETS_CONFIG=""
    BYPASS_RU_RULES=""
    DNS_RULES=""
    if [ "$BYPASS_RU" = "true" ]; then
        DNS_RULES='
      {
        "rule_set": [
          "geosite-category-ru",
          "geoip-ru"
        ],
        "server": "dns-direct"
      },'

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
          "gosuslugi.ru",
          "bybit.com"
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
AllowedIPs = 0.0.0.0/0
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
  "dns": {
    "servers": [
      {
        "type": "udp",
        "tag": "dns-direct",
        "server": "1.1.1.1"
      },
      {
        "type": "udp",
        "tag": "dns-vpn",
        "server": "8.8.8.8",
        "detour": "auto"
      }
    ],
    "rules": [
      $DNS_RULES
      {
        "domain_suffix": [
          "bybit.com"
        ],
        "server": "dns-direct"
      }
    ],
    "final": "dns-vpn",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "singtun0",
      "address": [
        "172.18.0.1/30"
      ],
      "auto_route": true,
      "strict_route": true,
      "stack": "gvisor"
    },
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": 1080
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
      {
        "outbound": "direct",
        "domain_suffix": [
          "bybit.com"
        ]
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
          "100.100.100.100/32",
          "192.144.12.164/32"
        ]
      },
      {
        "outbound": "direct",
        "ip_cidr": [
          "$VLESS_SERVER"
        ]
      },
      {
        "outbound": "direct",
        "domain_suffix": [
          "sharashin.ru"
        ]
      }
    ],
    "auto_detect_interface": true,
    "default_domain_resolver": "dns-vpn"
  }
}
EOF

    # Start Sing-box daemon
    sing-box run -c /etc/sing-box/config.json >/var/log/sing-box-run.log 2>&1 &
    SINGBOX_PID=$!

    # Set up normal exit-node NAT masquerading for awg0 (VPN tunnel NAT)
    iptables -t nat -A POSTROUTING -o awg0 -j MASQUERADE

    # Wait for singtun0 interface to exist
    for i in {1..20}; do
        if ip link show dev singtun0 >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done
    # Start Tailscaled
    mkdir -p /var/run/tailscale /var/lib/tailscale
    tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
    TAILSCALE_PID=$!

    sleep 2

    # Connect to Tailnet with retries
    # Attempt to reconnect using existing state first to preserve Headscale identity
    TS_CONNECTED=false
    if tailscale status >/dev/null 2>&1 && tailscale up --advertise-exit-node --accept-dns=false --snat-subnet-routes=true >/dev/null 2>&1; then
        echo "Tailscale reconnected using existing state."
        TS_CONNECTED=true
    else
        echo "Existing state missing or invalid, authenticating with auth-key..."
        for i in {1..5}; do
            if tailscale up \
              --login-server="$HEADSCALE_URL" \
              --auth-key="$TAILSCALE_AUTH_KEY" \
              --hostname="$TAILSCALE_HOSTNAME" \
              --advertise-exit-node \
              --accept-dns=false \
              --snat-subnet-routes=true; then
                TS_CONNECTED=true
                break
            fi
            echo "tailscale up attempt $i failed, retrying in 5s..." >&2
            sleep 5
        done
    fi

    if [ "$TS_CONNECTED" != "true" ]; then
        echo "Failed to connect to Tailscale after 5 attempts. Exiting..." >&2
        exit 1
    fi

    # Active Watchdog Loop (replacing wait -n)
    FAIL_COUNT=0
    MAX_FAILS=3
    CHECK_INTERVAL=30

    echo "Starting rsv exit-node watchdog loop..."
    while true; do
        sleep $CHECK_INTERVAL
        HEALTHY=true

        # 1. Process checks using signal 0
        if ! kill -0 $TAILSCALE_PID >/dev/null 2>&1; then
            echo "Watchdog alert: tailscaled process dead" >&2
            HEALTHY=false
        fi
        if ! kill -0 $SINGBOX_PID >/dev/null 2>&1; then
            echo "Watchdog alert: sing-box process dead" >&2
            HEALTHY=false
        fi

        # 2. Tailscale status check
        if [ "$HEALTHY" = "true" ]; then
            if ! tailscale status >/dev/null 2>&1; then
                echo "Watchdog alert: tailscale status check failed" >&2
                HEALTHY=false
            fi
        fi

        # 3. SOCKS proxy outbound connectivity check
        if [ "$HEALTHY" = "true" ]; then
            if ! curl -s --max-time 10 --socks5-hostname 127.0.0.1:1080 http://cp.cloudflare.com/generate_204 >/dev/null 2>&1; then
                echo "Watchdog alert: SOCKS proxy outbound probe failed" >&2
                HEALTHY=false
            fi
        fi

        if [ "$HEALTHY" = "true" ]; then
            FAIL_COUNT=0
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "Watchdog: consecutive failure count = $FAIL_COUNT / $MAX_FAILS" >&2
            if [ "$FAIL_COUNT" -ge "$MAX_FAILS" ]; then
                echo "Watchdog: Max failures reached. Exiting container to trigger auto-restart..." >&2
                exit 1
            fi
        fi
    done
  '';

  geoip-ru-srs = pkgs.fetchurl {
    url = "https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs";
    sha256 = "0w1i7h797pl2y44w9cw8wgsa92s20g6p9zx9l95n9c6mwlrq9hcb";
  };

  geosite-category-ru-srs = pkgs.fetchurl {
    url = "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-ru.srs";
    sha256 = "sha256-NTsS6Rqrsh6uFmuMR6Wgj2CF1cpjHiVtjXqAeRSoPMk=";
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
        pkgs.procps
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

  # Sort nodes alphabetically to ensure deterministic order and port mapping
  sortedNodes = builtins.sort (a: b: a < b) cfg.nodes;
  
  # Map each node name to a host port starting at 10800
  nodePorts = lib.listToAttrs (lib.imap0 (idx: name: {
    name = name;
    value = 10800 + idx;
  }) sortedNodes);

  # Helper function to generate exit node container definitions
  mkExitNodeContainer = id: node: {
    image = "rsv-exit-node:latest";
    ports = [
      "127.0.0.1:${toString nodePorts.${id}}:1080"
    ];
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--device=/dev/net/tun:/dev/net/tun"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
      "--sysctl=net.ipv4.ip_forward=1"
      "--dns=1.1.1.1"
      "--dns=8.8.8.8"
      "--health-cmd=curl -s --max-time 15 --socks5-hostname 127.0.0.1:1080 http://cp.cloudflare.com/generate_204 || exit 1"
      "--health-interval=30s"
      "--health-timeout=20s"
      "--health-retries=3"
    ];
    environmentFiles = [ "/run/rsv/env" ];
    environment = {
      TAILSCALE_HOSTNAME = node.hostname;
      HEADSCALE_URL = cfg.headscaleUrl;
      VPN_ADDRESS = head (splitString "," awgConfig.address);
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

    headscaleUrl = mkOption {
      type = types.str;
      description = "URL of the Headscale control plane server";
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
    systemd.services = {
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
    } // (genAttrs (map (id: "docker-rsv-${id}") cfg.nodes) (serviceName: {
      after = [ "rsv-prep-env.service" "rsv-load-image.service" ];
      wants = [ "rsv-prep-env.service" "rsv-load-image.service" ];
      serviceConfig = {
        Restart = mkForce "always";
        RestartSec = "10s";
      };
    }));

    virtualisation.oci-containers = {
      backend = "docker";
      containers = mapAttrs' (id: node: nameValuePair "rsv-${id}" (mkExitNodeContainer id node)) enabledNodes;
    };
  };
}
