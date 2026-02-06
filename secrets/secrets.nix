let
  pk = import ./pubkeys.nix;
in {
  "hy2-client.yaml.age".publicKeys = pk.all;
  "tailscale-auth-key.age".publicKeys = [pk.home-laptop2];
}
