let
  pk = import ./pubkeys.nix;
in {
  "test1.age".publicKeys = pk.all;
}
