{
  config,
  lib,
  pkgs,
  ...
}: {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://undercity.sharashin.ru";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";
      enable-login = true;
      enable-signup = false;
      cache-file = "/var/lib/ntfy-sh/cache.db";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
    };
  };

  environment.systemPackages = [ pkgs.ntfy-sh ];

  age.secrets = {
    ntfy-token.file = ../../secrets/ntfy-token.age;
    ntfy-admin-password.file = ../../secrets/ntfy-admin-password.age;
  };
}
