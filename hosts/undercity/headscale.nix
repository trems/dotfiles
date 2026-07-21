{
  config,
  lib,
  pkgs,
  ...
}: {
  # Headscale configuration
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;
    settings = {
      server_url = "https://undercity.sharashin.ru:18443";
      dns = {
        magic_dns = true;
        base_domain = "sharashin.mesh";
        override_local_dns = true;
        nameservers = {
          global = [ "1.1.1.1" "8.8.8.8" ];
          split = {
            "authng.k8s.dev-el" = [ "10.15.12.100" ];
            "k8s.tns-stage-el" = [ "10.15.12.100" ];
            "moderation-dm" = [ "10.15.12.100" ];
            "moderation-el" = [ "10.15.12.100" ];
            "nb.clv2" = [ "10.15.12.100" ];
            "rwb.ru" = [ "10.15.12.100" "10.15.12.200" ];
            "wb-cloud.ru" = [ "10.15.12.100" ];
            "wb.ru" = [ "10.15.12.100" "10.15.12.200" ];
            "wildberries.ru" = [ "10.15.12.100" "10.15.12.200" ];
          };
        };
      };
      policy = {
        mode = "file";
        path = "/etc/headscale/acl.hujson";
      };
    };
  };

  environment.etc."headscale/acl.hujson".text = builtins.toJSON {
    hosts = {
      "mbp" = "100.64.0.1";
      "oneplus12" = "100.64.0.8";
    };
    tagOwners = {
      "tag:lenovo" = [ "default@" ];
      "tag:exit-node" = [ "default@" ];
      "tag:client" = [ "default@" ];
    };
    autoApprovers = {
      routes = {
        "0.0.0.0/0" = [ "tag:exit-node" ];
        "::/0" = [ "tag:exit-node" ];
      };
      exitNode = [ "tag:exit-node" ];
    };
    acls = [
      {
        action = "accept";
        src = [ "mbp" ];
        dst = [
          "*:*"
          "10.0.0.0/8:*"
          "172.24.0.0/14:*"
          "172.28.0.0/18:*"
        ];
      }
      {
        action = "accept";
        src = [ "oneplus12" ];
        dst = [ "mbp:*" ];
      }
      {
        action = "accept";
        src = [ "*" ];
        dst = [ "autogroup:internet:*" ];
      }
    ];
  };

  # Open firewall ports:
  # - 18443 (Headscale client access)
  networking.firewall.allowedTCPPorts = [ 18443 ];
}
