# My Nix flake-based dotfiles

Flake-based Nix-Darwin+Home-Manager configuration and dotfiles.

Nix-Darwin manages home-manager installation, HM manages all the rest
(except some dotfiles, which symlinked to the `.config` dir).

## Install

1) Install Nix
2) Install nix-darwin
3) `sudo darwin-rebuild switch --flake ~/dotfiles/`
