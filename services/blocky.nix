{...}: let
  dnsPort = 53;
  httpPort = 4000;
in {
  networking.firewall = {
    allowedUDPPorts = [dnsPort];
    allowedTCPPorts = [dnsPort httpPort];
  };

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = dnsPort;
        http = httpPort;
      };
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
        "https://router.comss.one/dns-query"
      ];
      # For initially solving DoH/DoT Requests when no system Resolver is available.
      bootstrapDns = {
        upstream = "https://dns.cloudflare.com/dns-query";
        ips = ["1.1.1.1" "1.0.0.1"];
      };
      blocking = {
        denylists = {
          default = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"
            "https://blocklistproject.github.io/Lists/ads.txt"
            "https://raw.githubusercontent.com/Zalexanninev15/NoADS_RU/refs/heads/main/hosts/blockerFL.txt"
          ];
        };
        allowlists = {
          default = ["https://raw.githubusercontent.com/anudeepND/whitelist/refs/heads/master/domains/whitelist.txt"];
        };
        clientGroupsBlock = {
          default = ["default"];
        };
      };
      prometheus = {
        enable = true;
        path = "/metrics";
      };
    };
  };
}
