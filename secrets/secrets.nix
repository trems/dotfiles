let
  pk = import ./pubkeys.nix;
in {
  "hysteria-client-conf.age".publicKeys = pk.all;
}
