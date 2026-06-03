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
    export PATH="${lib.makeBinPath [ pkgs.iptables pkgs.iproute2 pkgs.amneziawg-go amneziawg-tools-custom pkgs.tailscale pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.gawk sysctl-wrapper pkgs.xray ]}:$PATH"
    export WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go
    export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt

    # Ensure required directories exist
    mkdir -p /tmp /dev/net /var/log
    if [ ! -c /dev/net/tun ]; then
        mknod /dev/net/tun c 10 200
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

    # Apply global forwarding rules for the VPN interface
    iptables -A FORWARD -i awg0 -j ACCEPT
    iptables -A FORWARD -o awg0 -j ACCEPT

    # Setup Xray if bypassRu is enabled
    if [ "$BYPASS_RU" = "true" ]; then
        echo "Setting up Xray for Russian subnet bypass..."
        
        # Prepare asset directory
        mkdir -p /var/lib/xray
        ln -sf ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat /var/lib/xray/geoip.dat
        ln -sf ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat /var/lib/xray/geosite.dat

        # Fetch/update zapret.dat from GitHub if missing or older than 24h
        ZAPRET_FILE="/var/lib/tailscale/zapret.dat"
        if [ ! -f "$ZAPRET_FILE" ] || [ -n "$(find "$ZAPRET_FILE" -mmin +1440 2>/dev/null)" ]; then
            echo "Downloading latest zapret.dat..."
            if curl -s -f -L -o "$ZAPRET_FILE.tmp" "https://github.com/kutovoys/ru_gov_zapret/releases/latest/download/zapret.dat"; then
                if [ -s "$ZAPRET_FILE.tmp" ]; then
                    mv "$ZAPRET_FILE.tmp" "$ZAPRET_FILE"
                    echo "zapret.dat updated successfully."
                else
                    echo "Error: Downloaded zapret.dat is empty!"
                    rm -f "$ZAPRET_FILE.tmp"
                fi
            else
                echo "Warning: failed to download zapret.dat, using cached version."
            fi
        fi

        if [ -f "$ZAPRET_FILE" ]; then
            ln -sf "$ZAPRET_FILE" /var/lib/xray/zapret.dat
        else
            echo "Error: zapret.dat is missing! Xray may fail to start."
        fi

        # Start Xray daemon
        export XRAY_LOCATION_ASSET=/var/lib/xray
        xray run -config /etc/xray/config.json >/var/log/xray-run.log 2>&1 &

        # Set up NAT masquerading for eth0 (bypassed traffic NAT)
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

        # Set up iptables REDIRECT rules for Xray TCP traffic
        iptables -t nat -N XRAY
        iptables -t nat -A PREROUTING -i tailscale0 -j XRAY
        iptables -t nat -A XRAY -d 0.0.0.0/8 -j RETURN
        iptables -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
        iptables -t nat -A XRAY -d 100.64.0.0/10 -j RETURN
        iptables -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
        iptables -t nat -A XRAY -d 169.254.0.0/16 -j RETURN
        iptables -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
        iptables -t nat -A XRAY -d 192.168.0.0/16 -j RETURN
        iptables -t nat -A XRAY -d 224.0.0.0/4 -j RETURN
        iptables -t nat -A XRAY -d 240.0.0.0/4 -j RETURN
        iptables -t nat -A XRAY -d 100.100.100.100/32 -j RETURN
        iptables -t nat -A XRAY -p tcp -j REDIRECT --to-ports 12345
        echo "Xray and redirection rules set up successfully."
    fi

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

  xrayConfigFile = pkgs.writeTextFile {
    name = "xray-config.json";
    destination = "/etc/xray/config.json";
    text = builtins.toJSON {
      log = {
        loglevel = "warning";
      };
      dns = {
        servers = [
          "8.8.8.8"
          "1.1.1.1"
          "100.100.100.100"
        ];
      };
      inbounds = [
        {
          listen = "0.0.0.0";
          port = 12345;
          protocol = "dokodemo-door";
          tag = "redir-in";
          settings = {
            network = "tcp";
            followRedirect = true;
          };
          sniffing = {
            enabled = true;
            destOverride = [ "http" "tls" "quic" ];
            routeOnly = true;
          };
        }
      ];
      outbounds = [
        {
          protocol = "freedom";
          tag = "vpn";
          settings = {};
        }
        {
          protocol = "freedom";
          tag = "direct";
          settings = {};
          streamSettings = {
            sockopt = {
              mark = 51820; # 0xca6c
            };
          };
        }
        {
          protocol = "blackhole";
          tag = "block";
        }
      ];
      routing = {
        domainStrategy = "AsIs";
        rules = [
          {
            type = "field";
            domain = [
              "domain:chatgpt.com"
              "domain:openai.com"
              "geosite:openai"
              "geosite:google"
              "geosite:youtube"
              "domain:gemini.google.com"
              "ext:zapret.dat:zapret"
              "ext:zapret.dat:zapret-zapad"
            ];
            outboundTag = "vpn";
          }
          {
            type = "field";
            domain = [
              "domain:kinopoisk.ru"
              "domain:hd.kinopoisk.ru"
              "domain:yandex.ru"
              "domain:yandex.net"
              "domain:vk.com"
              "domain:gosuslugi.ru"
              "geosite:category-ru"
            ];
            outboundTag = "direct";
          }
          {
            type = "field";
            ip = [ "geoip:ru" ];
            outboundTag = "direct";
          }

          {
            type = "field";
            inboundTag = [ "redir-in" ];
            ip = [ "geoip:private" ];
            outboundTag = "direct";
          }
          {
            type = "field";
            network = "tcp,udp";
            outboundTag = "vpn";
          }
        ];
      };
    };
  };

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
        pkgs.xray
        xrayConfigFile
      ];
      pathsToLink = [ "/bin" "/etc" ];
    };
    config = {
      Cmd = [ "/bin/entrypoint" ];
    };
  };

  locations = builtins.fromJSON (builtins.readFile ./redshield-locations.json);

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
      VPN_ADDRESS = "10.41.9.11/32,2010:db0:3::a29:90b/128";
      VPN_PUBLIC_KEY = "Q/Yd6t2NgifQ6AeLzjVixOedsMYRQO7786fN75a223A=";
      VPN_DNS = "10.254.254.254";
      VPN_ENDPOINT = node.endpoint;
      BYPASS_RU = if node.bypassRu then "true" else "false";
      AWG_JC = "3";
      AWG_JMIN = "40";
      AWG_JMAX = "70";
      AWG_S1 = "35";
      AWG_S2 = "89";
      AWG_S3 = "97";
      AWG_S4 = "20";
      AWG_H1 = "168781656-175897653";
      AWG_H2 = "218638374-232742829";
      AWG_H3 = "310726521-327400208";
      AWG_H4 = "425164664-434856083";
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
    }));

    virtualisation.oci-containers = {
      backend = "docker";
      containers = mapAttrs' (id: node: nameValuePair "rsv-${id}" (mkExitNodeContainer id node)) enabledNodes;
    };
  };
}
