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
    agenix.url = "github:yaxitech/ragenix";
    deploy-rs.url = "github:serokell/deploy-rs";
    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = inputs @ {
    self,
    darwin,
    nixpkgs,
    mac-app-util,
    home-manager,
    deploy-rs,
    agenix,
  }: let
    publicKeys = import ./secrets/pubkeys.nix;
    systemDarwin = "aarch64-darwin";
    systemLinux = "x86_64-linux";
    pkgsDarwin = import nixpkgs {
      system = systemDarwin;
      config.allowUnfree = true;
    };
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
    mkDarwinSystem = {
      user,
      arch ? systemDarwin,
    }:
      darwin.lib.darwinSystem {
        system = arch;
        modules = [
          {
            _module.args = {
              inherit user inputs publicKeys;
            };
          }
          ./darwin
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              users.${user} = import ./home;
              sharedModules = [
                mac-app-util.homeManagerModules.default
              ];
            };
            users.users.${user}.home = "/Users/${user}";
            nix = nixSettings user;
            age = {
              # identityPaths = ["/Users/${user}/.ssh/id_ed25519"];
              secrets = {
                test1 = {
                  file = ./secrets/test1.age;
                  owner = user;
                };
              };
            };
          }
          agenix.darwinModules.default
        ];
      };
  in {
    # Build darwin flake using:
    # $ sudo darwin-rebuild build --flake .#macbook-air-m1
    darwinConfigurations = {
      "IT-MAC-NB165" = mkDarwinSystem {
        user = "msharashin";
      };
      "macbook-air-m1" = mkDarwinSystem {
        user = "m";
      };
    };
    nixosConfigurations = {
      home-laptop2 = nixpkgs.lib.nixosSystem {
        system = systemLinux;
        modules = [
          ./hosts/home-laptop2/configuration.nix
          {
            _module.args = {inherit publicKeys;};
            nix = nixSettings "mike";
            age = {
              secrets = {
                test1 = {
                  file = ./secrets/test1.age;
                };
              };
            };
          }
          agenix.nixosModules.default
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
        pkgsDarwin.deploy-rs
        fish
        agenix.packages.${systemDarwin}.default
      ];
      shellHook = ''
        exec fish
      '';
    };
  };
}
