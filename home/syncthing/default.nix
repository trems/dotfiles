{
  config,
  pkgs,
  mkMutableSymlink,
  dotfiles,
  ...
}:

{
  services.syncthing = {
    enable = true;
    tray = true;
    settings = {
      devices = {
        phone = {
          id = "KYC7B2F-WL7SSA3-MFC6YQL-ZGMZWLF-XQB6LZR-HVUN3DI-QK5F5AB-TQDBPQL";
        };
      };
    };
  };

}
