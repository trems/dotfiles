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
    agenix.url = "github:ryantm/agenix";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = inputs @ {
    self,
    darwin,
    nixpkgs,
    home-manager,
    deploy-rs,
    agenix,
  }: let
    systemDarwin = "aarch64-darwin";
    systemLinux = "x86_64-linux";
    pkgsDarwin = import nixpkgs {system = systemDarwin;};
    pkgsLinux = import nixpkgs {system = systemLinux;};
    forAllSystems = nixpkgs.lib.genAttrs [systemLinux systemDarwin];
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
          ./darwin
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
          agenix.darwinModules.default
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
        modules = [
          ./hosts/home-laptop2/configuration.nix
          {
            nix = nixSettings "mike";
          }
        ];
      };
    };
    deploy = {
      nodes = {
        home-laptop2 = {
          remoteBuild = true;
          hostname = "home-laptop2";
          sshUser = "mike";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${systemLinux}.activate.nixos self.nixosConfigurations.home-laptop2;
          };
        };
      };
    };

    # `nix flake check`
    # checks = forAllSystems (system: let
    #   pkgs = nixpkgs.legacyPackages.${system};
    #   deploy-rs-checks = deploy-rs.lib.${system}.deployChecks self.deploy;
    # in
    #   with pkgs;
    #     lib.optionalAttrs stdenv.isLinux deploy-rs-checks
    #     // {
    #       # Your other usual checks can go here, e.g. deadnix, formatter, pre-commit, ...
    #     });

    # `nix develop`
    devShells."${systemDarwin}".default = pkgsDarwin.mkShell {
      buildInputs = with pkgsDarwin; [
        deploy-rs
        fish
        # age
        # ssh-to-age
        # agenix.packages.${system}.default
      ];
      shellHook = ''
        exec fish
      '';
    };
  };
}
