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
      "macbook-air-m1" = "100.64.0.18";
      "home-laptop2" = "100.64.0.2";
    };
    tagOwners = {
      "tag:lenovo" = [ "default@" ];
      "tag:exit-node" = [ "default@" ];
      "tag:client" = [ "default@" ];
    };
    # Automatically approve default exit node routes (0.0.0.0/0 and ::/0) for tagged exit nodes
    # Required for ephemeral rsv-* Docker containers so exit routes become active without manual intervention
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
        dst = [
          "mbp:*"
          "home-laptop2:*"
          # Herdr Android → herdr-core на Lenovo (Tailscale SSH, правило ssh ниже)
          "tag:lenovo:22"
          "tag:exit-node:*"
          "autogroup:internet:*"
        ];
      }
      {
        action = "accept";
        src = [ "macbook-air-m1" ];
        dst = [
          "mbp:*"
          "tag:exit-node:*"
          "autogroup:internet:*"
        ];
      }
      # корпоративный Lenovo: только HTTP-прокси sing-box для LLM API (services/sing-box.nix)
      {
        action = "accept";
        src = [ "tag:lenovo" ];
        dst = [ "home-laptop2:1081" ];
      }
    ];
    # Tailscale SSH на корпоративный Lenovo (на ноде нужен `tailscale set --ssh`)
    ssh = [
      {
        action = "accept";
        src = [ "default@" ];
        dst = [ "tag:lenovo" ];
        users = [ "sharashin.mihail" ];
      }
      # Tailscale SSH на home-laptop2 (services.tailscale.extraSetFlags в его configuration.nix)
      {
        action = "accept";
        src = [ "default@" ];
        dst = [ "tag:client" ];
        users = [ "mike" ];
      }
    ];
  };

  # политику из файла headscale перечитывает только по SIGHUP
  systemd.services.headscale = {
    reloadTriggers = [ config.environment.etc."headscale/acl.hujson".source ];
    serviceConfig.ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
  };

  # Open firewall ports:
  # - 18443 (Headscale client access)
  networking.firewall.allowedTCPPorts = [ 18443 ];
}
