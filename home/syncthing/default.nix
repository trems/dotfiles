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
    tray = {
      enable = false;
    };
    guiAddress = "127.0.0.1:8384";
    settings = {
      devices = {
        phone = {
          id = "KYC7B2F-WL7SSA3-MFC6YQL-ZGMZWLF-XQB6LZR-HVUN3DI-QK5F5AB-TQDBPQL";
        };
      };
      folders = {
        "obsidian-vaults" = {
          enable = true;
          id = "9uxkv-kkef5";
          path = "~/obsidian";
          devices = [ "phone" ];
          type = "sendreceive";
        };
      };
    };
  };

}
