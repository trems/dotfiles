let
  pk = import ./pubkeys.nix;
in {
  "hy2-client-conf.yaml.age".publicKeys = pk.all;
  "tailscale-auth-key.age".publicKeys = [pk.home-laptop2];
}
