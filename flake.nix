{
  # initial installation of nix-darwin: nix run nix-darwin -- switch --flake .
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # colmena.url = "github:zhaofengli/colmena";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = inputs @ {
    self,
    darwin,
    nixpkgs,
    home-manager,
    deploy-rs,
    sops-nix,
  }: let
    systemDarwin = "aarch64-darwin";
    systemLinux = "x86_64-linux";
    pkgsDarwin = import nixpkgs {system = systemDarwin;};
    pkgsLinux = import nixpkgs {system = systemLinux;};
    nixSettings = user: {
      settings = {
        trusted-users = [user];
        extra-experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
    };
    darwinSystem = {
      user,
      arch ? systemDarwin,
    }:
      darwin.lib.darwinSystem {
        system = arch;
        modules = [
          ./darwin/darwin.nix
          home-manager.darwinModules.home-manager
          {
            _module.args = {inherit inputs;};
            home-manager = {
              users.${user} = import ./home;
              sharedModules = [];
            };
            users.users.${user}.home = "/Users/${user}";
            nix = nixSettings user;
          }
          sops-nix.darwinModules.sops
        ];
      };
  in {
    # Build darwin flake using:
    # $ sudo darwin-rebuild build --flake .#IT-MAC-NB165
    darwinConfigurations = {
      "IT-MAC-NB165" = darwinSystem {
        user = "msharashin";
      };
    };
    nixosConfigurations = {
      home-laptop2 = nixpkgs.lib.nixosSystem {
        system = systemLinux;
        modules = [./hosts/home-laptop2/configuration.nix];
      };
    };
    deploy = {
      remoteBuild = true;
      nodes = {
        home-laptop2 = {
          hostname = "192.168.0.102";
          profiles.system = {
            user = "mike";
            path = deploy-rs.lib.${systemLinux}.activate.nixos self.nixosConfigurations.home-laptop2;
          };
        };
      };
    };
    # This is highly advised, and will prevent many possible mistakes
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    # `nix develop`
    devShells."${systemDarwin}".default = pkgsDarwin.mkShell {
      buildInputs = with pkgsDarwin; [
        # colmena.defaultPackage.${systemDarwin}
        pkgsDarwin.deploy-rs
        fish
        sops
        age
        ssh-to-age
      ];
      shellHook = ''
        # by default it expect keys at $HOME/Library/Application Support/sops/age/keys.txt on nix-darwin
        export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
        exec fish
      '';
    };
  };
}
