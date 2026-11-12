let
  pk = import ./pubkeys.nix;
in {
  "hy2-client.yaml.age".publicKeys = pk.all;
  "hys2/server.age".publicKeys = pk.all;
  "hys2/auth.age".publicKeys = pk.all;
  "hys2/obfs-pass.age".publicKeys = pk.all;
  "rs-private-key.age".publicKeys = pk.all;
  "tailscale-auth-key.age".publicKeys = pk.all;
  "tailscale-exit-node-auth-key.age".publicKeys = pk.all;
  "tailscale-ironforge-auth-key.age".publicKeys = pk.all;
  "subscription-uuid.age".publicKeys = pk.all;
  "ntfy-token.age".publicKeys = pk.all;
  "ntfy-admin-password.age".publicKeys = pk.all;
  "wb/tns-ai-key.age".publicKeys = with pk; [mbp lenovo];
}
