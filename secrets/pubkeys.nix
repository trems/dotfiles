rec {
  ucb-mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLeUpRLdLM9bNaZ2utFfHtw4MPIlj3vo6UjW2aFE9eA msharashin@IT-MAC-NB165.local";
  home-laptop2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIteJxePAOsUTL2ZANy1jXwzhbt/UepwU1U+Iq/1pkj1";
  macbook-air-m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwp9iE82eLzcNgZl+YxWnI6V+vrjMHb5natHrQc/BkW";

  all = [ucb-mbp home-laptop2 macbook-air-m1];
}
