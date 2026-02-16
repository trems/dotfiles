let
  pk = import ./pubkeys.nix;
in {
  "hy2-client.yaml.age".publicKeys = pk.all;
  "tailscale-auth-key.age".publicKeys = [pk.home-laptop2];
  "hys2/server.age".publicKeys = pk.all;
  "hys2/auth.age".publicKeys = pk.all;
  "hys2/obfs-pass.age".publicKeys = pk.all;
}
