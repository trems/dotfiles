{...}: let
in {
  services.rqbit = {
    enable = true;
    peerPort = 4240;
    httpPort = 3030;
    httpHost = "0.0.0.0";
    openFirewall = true;
    downloadDir = "/var/lib/rqbit/downloads";
  };
}
