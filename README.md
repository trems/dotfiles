# My Nix flake-based dotfiles

Flake-based Nix-Darwin+Home-Manager configuration and dotfiles.

Nix-Darwin manages home-manager installation, HM manages all the rest
(except some dotfiles, which symlinked to the `.config` dir).

## Overview

This repository contains a comprehensive configuration system for managing macOS dotfiles using Nix flakes, nix-darwin, and Home Manager. It provides a declarative approach to system configuration management, allowing for reproducible and version-controlled setups across multiple machines.

The configuration includes:
- macOS system-level settings (Finder, Dock, keyboard, etc.)
- User-level configurations (shell environments, editors, tools)
- Development environment with modern tools and utilities
- Service configurations (Syncthing, Git-sync)
- Encrypted secrets management using agenix

## Prerequisites

Before installing this configuration, ensure you have:

1. **Nix package manager** installed
2. **Nix-Darwin** installed
3. Basic understanding of Nix expressions and flakes
4. Administrative privileges for system-level changes

## Install

1. Install Nix:
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. Install nix-darwin:
   ```bash
   nix run nix-darwin -- switch --flake ~/.config/darwin
   ```

   Or if you're starting fresh:
   ```bash
   nix run github:LnL7/nix-darwin -- switch --flake .
   ```

3. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
   ```

4. Apply the configuration:
   ```bash
   sudo darwin-rebuild switch --flake ~/dotfiles/
   ```

## Architecture

The configuration follows a modular structure:

- **nix-darwin**: Manages macOS system-level configurations
- **Home Manager**: Handles user-level configurations and dotfiles
- **Agenix**: Encrypts sensitive configuration data
- **Deploy-rs**: Enables remote deployment capabilities

## Features

- **Modern CLI tools**: Includes eza, fd, ripgrep, fzf, and other productivity tools
- **Development environment**: Configured for Go, Rust, Node.js, and other languages
- **Shell environments**: Fish shell with custom functions and aliases
- **Editor integration**: Neovim configured as the default editor
- **Git enhancements**: Git with Delta for enhanced diffs
- **Security**: Encrypted secrets management with agenix

## Directory Structure

```
dotfiles/
├── darwin/                 # macOS-specific system configurations
├── home/                   # User-level configurations managed by Home Manager
│   ├── bat/               # Bat configuration
│   ├── direnv/            # Direnv configuration
│   ├── eza/               # Eza configuration
│   ├── fd/                # FD configuration
│   ├── fish/              # Fish shell configuration
│   ├── fzf/               # FZF configuration
│   ├── git/               # Git configuration
│   ├── git-sync/          # Git sync service
│   ├── lazygit/           # Lazygit configuration
│   ├── nvim/              # Neovim configuration
│   ├── wezterm/           # Terminal emulator configuration
│   ├── zoxide/            # Zoxide configuration
│   └── syncthing/         # Syncthing service configuration
├── hosts/                  # Host-specific configurations
├── secrets/                # Encrypted secrets
├── services/               # Additional services
└── flake.nix               # Main flake definition
```

## Usage

### Updating Configuration

To update and apply the configuration:
```bash
sudo darwin-rebuild switch --flake ~/dotfiles/
```

### Updating Flakes

To update all flake inputs:
```bash
nix flake update ~/dotfiles/
```

### Building Without Applying

To test the configuration without applying it:
```bash
sudo darwin-rebuild build --flake ~/dotfiles/
```

## Managing Secrets

This configuration uses [agenix](https://github.com/yaxitech/ragenix) to manage encrypted secrets using Age encryption.

### Prerequisites

Make sure you have `agenix` in your shell environment:
```bash
nix profile install github:yaxitech/ragenix
# Or if using the development shell:
nix develop
```

### Working with Secrets

#### Adding and Editing Secrets

To create or edit a secret file, use:
```bash
agenix --edit secrets/my-secret.txt
```
This will open an editor where you can add your secret content, which will be automatically encrypted.

#### Adding New Machines/Keys

1. Add your public key to `secrets/pubkeys.nix`
2. Re-encrypt all secrets with the new keyset using:
```bash
agenix --rekey
```

### Using Secrets in Configurations

Secrets are made available in your system via the nix-darwin age module. They will be placed at `/run/agenix/SECRET_NAME` and can be referenced in your configurations. For example:

```nix
environment.etc."my-config".source = config.age.secrets.my-secret.path;
```

## Common Operations

### Adding New Packages

Add packages to `home/default.nix` in the `home.packages` section:
```nix
home.packages = with pkgs; [
  # existing packages...
  new-package-name
];
```

### Modifying Shell Configuration

Shell-specific configurations are in `home/fish/default.nix`. Add functions, aliases, or initialization code there.

### Changing Git Settings

Modify `home/git/default.nix` to update user information, aliases, or other Git settings.

## Troubleshooting

### Configuration Not Applying

If changes aren't taking effect, try rebuilding:
```bash
sudo darwin-rebuild build --flake ~/dotfiles/
sudo darwin-rebuild switch --flake ~/dotfiles/
```

### Missing Packages

Ensure packages are listed in `home/packages` in `home/default.nix` and rebuild.

### Secret Decryption Errors

- Verify your SSH private key matches a public key in `secrets/pubkeys.nix`
- Check that the age identity file paths are correctly configured in `flake.nix`
- Ensure `agenix` is properly installed in your environment

### Permission Issues

Some operations require sudo due to system-level changes required by nix-darwin.

## Development

To contribute to this configuration:

1. Fork and clone the repository
2. Make changes in a feature branch
3. Test with `darwin-rebuild build` before applying
4. Submit a pull request with your changes

The configuration is organized modularly to make changes easy to locate and implement.
