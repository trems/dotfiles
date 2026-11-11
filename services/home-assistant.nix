{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.my-home-assistant;
in {
  options.services.my-home-assistant = {
    enable = lib.mkEnableOption "Home Assistant Stack with Matter Server and HACS";

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/homeassistant";
      description = "Path to Home Assistant configuration directory";
    };

    matterDataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/matter-server";
      description = "Path to Matter Server data directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open required ports in firewall for Home Assistant, Matter and HomeKit/mDNS";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    # Ensure directories exist with proper permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0755 root root -"
      "d ${cfg.matterDataDir} 0755 root root -"
      "d /var/lib/miloco 0755 root root -"
      "d /var/lib/go2rtc 0755 root root -"
    ];

    # Pre-install HACS into custom_components if not present
    systemd.services.home-assistant-hacs-setup = {
      description = "Download and setup HACS for Home Assistant";
      wantedBy = ["multi-user.target"];
      before = ["docker-homeassistant.service"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = with pkgs; [curl unzip coreutils];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p "${cfg.configDir}/custom_components"
        if [ ! -d "${cfg.configDir}/custom_components/hacs" ]; then
          echo "HACS not found. Downloading latest release..."
          TMP_DIR=$(mktemp -d)
          curl -sSL "https://github.com/hacs/integration/releases/latest/download/hacs.zip" -o "$TMP_DIR/hacs.zip"
          mkdir -p "${cfg.configDir}/custom_components/hacs"
          unzip -q "$TMP_DIR/hacs.zip" -d "${cfg.configDir}/custom_components/hacs"
          rm -rf "$TMP_DIR"
          echo "HACS installed successfully."
        else
          echo "HACS is already installed."
        fi
      '';
    };

    systemd.services.docker-homeassistant = {
      after = ["home-assistant-hacs-setup.service"];
      wants = ["home-assistant-hacs-setup.service"];
    };

    virtualisation.oci-containers.containers = {
      homeassistant = {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        autoStart = true;
        extraOptions = [
          "--network=host"
          "--privileged"
        ];
        environment = {
          TZ = config.time.timeZone;
        };
        volumes = [
          "${cfg.configDir}:/config"
          "/etc/localtime:/etc/localtime:ro"
          "/run/dbus:/run/dbus:ro"
        ];
      };

      matter-server = {
        image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
        autoStart = true;
        extraOptions = [
          "--network=host"
          "--security-opt=apparmor:unconfined"
        ];
        volumes = [
          "${cfg.matterDataDir}:/data"
          "/run/dbus:/run/dbus:ro"
        ];
        cmd = [
          "--storage-path"
          "/data"
        ];
      };

      miloco = {
        image = "ghcr.io/miiot/miloco:main";
        autoStart = true;
        extraOptions = [
          "--network=host"
        ];
        environment = {
          BACKEND_PORT = "8000";
          BACKEND_LOG_LEVEL = "warning";
          TZ = config.time.timeZone;
        };
        volumes = [
          "/var/lib/miloco:/app/miloco_server/.temp"
        ];
      };

      go2rtc = {
        image = "alexxit/go2rtc:latest";
        autoStart = true;
        extraOptions = [
          "--network=host"
          "--privileged"
        ];
        environment = {
          TZ = config.time.timeZone;
        };
        volumes = [
          "/var/lib/go2rtc:/config"
        ];
      };
    };

    # Avahi for local mDNS discovery (used by HomeKit, Matter, Cast, etc.)
    services.avahi = {
      enable = true;
      nssmdns4 = true;
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      trustedInterfaces = [ "wlp1s0" "docker0" ];
      allowedTCPPorts = [
        8123 # Home Assistant Web UI & API
        5580 # Python Matter Server WebSocket
        8000 # Xiaomi Miloco Web UI
        1984 # go2rtc Web UI & API
        8554 # RTSP Stream Port
        8555 # WebRTC TCP Port
        21063 # HomeKit Bridge
        51827 # HomeKit Bridge default
      ];
      allowedUDPPorts = [
        5353 # mDNS (Matter, HomeKit, Cast, ESPHome)
        5540 # Matter Commissioning & Operational traffic
        1900 # SSDP / UPnP discovery
        8555 # WebRTC UDP Port
      ];
    };
  };
}
