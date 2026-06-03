{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.redshield-exit-nodes;

  sysctl-wrapper = pkgs.writeShellScriptBin "sysctl" ''
    echo "sysctl wrapper called with: $@" >&2
    for arg in "$@"; do
      if [[ "$arg" == *src_valid_mark=1* || "$arg" == *ip_forward=1* ]]; then
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
    export PATH="${lib.makeBinPath [ pkgs.iptables pkgs.iproute2 pkgs.amneziawg-go amneziawg-tools-custom pkgs.tailscale pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.gawk sysctl-wrapper ]}:$PATH"
    export WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go

    # Ensure required directories exist
    mkdir -p /tmp /dev/net
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

# NAT rules to masquerade Tailscale exit node traffic out through AmneziaWG
PostUp = iptables -t nat -A POSTROUTING -o %i -j MASQUERADE; iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o %i -j MASQUERADE; iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
PublicKey = $VPN_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $VPN_ENDPOINT
PersistentKeepalive = 25
EOF

    # Optional: Fetch Russian subnets list before VPN default route takes over
    if [ "$BYPASS_RU" = "true" ]; then
        echo "Fetching Russian subnets list..."
        ORIG_GW=$(ip route show default | grep eth0 | awk '{print $3}' | head -n1)
        if [ -n "$ORIG_GW" ]; then
            echo "Original gateway detected: $ORIG_GW"
            export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
            for i in {1..5}; do
                if curl -s -f https://raw.githubusercontent.com/ipverse/country-ip-blocks/master/country/ru/ipv4-aggregated.txt > /tmp/ru-ips.txt; then
                    echo "Russian IP list fetched successfully."
                    break
                fi
                echo "Fetch failed, retrying in 2 seconds (attempt $i of 5)..."
                sleep 2
            done
        else
            echo "Error: Could not locate original default gateway."
        fi
    fi

    # Start AmneziaWG userspace tunnel
    awg-quick up awg0

    # Optional: Bypass Russian subnets directly via container's host gateway
    if [ "$BYPASS_RU" = "true" ] && [ -s /tmp/ru-ips.txt ]; then
        echo "Configuring direct route bypass for Russian subnets..."
        awk -v gw="$ORIG_GW" '/^#/ || /^$/ { next } {print "route add " $1 " via " gw " dev eth0"}' /tmp/ru-ips.txt > /tmp/route-batch.txt
        ip -batch /tmp/route-batch.txt || true
        echo "Direct routes applied successfully."
    fi

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
      "/var/lib/rsv-multitun/${removePrefix "rsv-" id}:/var/lib/tailscale"
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
    } // (genAttrs (map (id: "docker-${id}") cfg.nodes) (serviceName: {
      after = [ "rsv-prep-env.service" "rsv-load-image.service" ];
      wants = [ "rsv-prep-env.service" "rsv-load-image.service" ];
    }));

    virtualisation.oci-containers = {
      backend = "docker";
      containers = mapAttrs (id: node: mkExitNodeContainer id node) enabledNodes;
    };
  };
}
