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
    colmena.url = "github:zhaofengli/colmena";
  };

  outputs =
    inputs@{
      self,
      darwin,
      nixpkgs,
      home-manager,
      colmena,
    }:
    let
      systemDarwin = "aarch64-darwin";
      pkgsDarwin = import nixpkgs { system = systemDarwin; };
      nixSettings = user: {
        settings = {
          trusted-users = [ user ];
          extra-experimental-features = [
            "nix-command"
            "flakes"
          ];
        };
      };
      darwinSystem =
        {
          user,
          arch ? systemDarwin,
        }:
        darwin.lib.darwinSystem {
          system = arch;
          modules = [
            ./darwin/darwin.nix
            home-manager.darwinModules.home-manager
            {
              _module.args = { inherit inputs; };
              home-manager = {
                users.${user} = import ./home;
                sharedModules = [ ];
              };
              users.users.${user}.home = "/Users/${user}";
              nix = nixSettings user;
            }
          ];
        };
    in
    {
      # Build darwin flake using:
      # $ sudo darwin-rebuild build --flake .#IT-MAC-NB165
      darwinConfigurations = {
        "IT-MAC-NB165" = darwinSystem {
          user = "msharashin";
        };
      };

      # nix develop
      devShells."${systemDarwin}".default = pkgsDarwin.mkShell {
        buildInputs = with pkgsDarwin; [
          colmena.defaultPackage.${systemDarwin}
          fish
          sops
        ];
        shellHook = ''
          exec fish
        '';
      };
    };
}
