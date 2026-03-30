{
  description = "NixOS Konfiguration - leonardn";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-code-nix, home-manager, ... }: {
    nixosConfigurations.leonardn = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self; };
      modules = [
        ./hosts/leonardn
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.leonardn = import ./home;
        }
        {
          environment.systemPackages = [
            claude-code-nix.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
