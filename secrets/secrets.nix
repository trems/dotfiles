let
  msharashin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLeUpRLdLM9bNaZ2utFfHtw4MPIlj3vo6UjW2aFE9eA msharashin@IT-MAC-NB165.local";
  home-laptop2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIteJxePAOsUTL2ZANy1jXwzhbt/UepwU1U+Iq/1pkj1";
in {
  "test1.age".publicKeys = [msharashin];
}
