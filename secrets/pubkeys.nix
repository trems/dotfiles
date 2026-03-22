rec {
  home-laptop2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIteJxePAOsUTL2ZANy1jXwzhbt/UepwU1U+Iq/1pkj1";
  macbook-air-m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeZ2pZ4j1wQReMRGYSe2JV/DVrVjlccBBiIOnpoW/gk m@macbook-air-m1.local";
  mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKQ2fKPpQzJBbTpT0Vtw78vdPGRAsavDNHc2NkdAEBwj m@mbp.local"

  all = [home-laptop2 macbook-air-m1 mbp];
}
