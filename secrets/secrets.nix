let
  pk = import ./pubkeys.nix;
in {
  "hysteria-client-conf.age".publicKeys = pk.all;
  "tailscale-auth-key.age".publicKeys = [pk.home-laptop2];
}
