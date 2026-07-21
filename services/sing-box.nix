{
  config,
  pkgs,
  lib,
  ...
}: let
  # Dynamically list enabled exit nodes on home-laptop2
  activeNodes = config.services.redshield-exit-nodes.nodes;

  # Load mapping from redshield-locations.json (in the same directory)
  locations = builtins.fromJSON (builtins.readFile ./redshield-locations.json);

  # Helper to resolve tailscale hostname for a location
  getHostName = name:
    if locations ? ${name}
    then locations.${name}.hostname
    else "rsv-${name}";

  # Sort nodes alphabetically to ensure deterministic order and port mapping
  sortedNodes = builtins.sort (a: b: a < b) activeNodes;
  
  # Map each node name to a host port starting at 10800
  nodePorts = lib.listToAttrs (lib.imap0 (idx: name: {
    name = name;
    value = 10800 + idx;
  }) sortedNodes);

  # Dynamically build SOCKS outbounds pointing to each exit node
  rsvOutbounds = map (name: {
    type = "socks";
    tag = getHostName name;
    server = "127.0.0.1";
    server_port = nodePorts.${name};
  }) activeNodes;

  # List of tags for urltest group
  rsvTags = map (name: getHostName name) activeNodes;
in {
  services.sing-box = {
    enable = true;
    settings = {
      log.level = "info";

      inbounds = [
        {
          type = "socks";
          tag = "socks-in";
          listen = "127.0.0.1";
          listen_port = 1080;
        }
        {
          type = "http";
          tag = "http-in";
          listen = "127.0.0.1";
          listen_port = 1081;
        }
      ];

      outbounds = [
        {
          type = "direct";
          tag = "direct-out";
        }
        {
          type = "urltest";
          tag = "rsv-auto";
          outbounds = rsvTags;
          url = "https://chatgpt.com";
          interval = "1m";
          tolerance = 50;
        }
      ] ++ rsvOutbounds;

      route = {
        auto_detect_interface = false;
        rules = [
          {
            domain_suffix = [
              "openai.com"
              "chatgpt.com"
            ];
            outbound = "rsv-auto";
          }
          {
            outbound = "direct-out";
          }
        ];
      };
    };
  };
}
