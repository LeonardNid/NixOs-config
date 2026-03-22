{
  description = "Mein erstes NixOS Flake Setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-code-nix, home-manager, ... }: {
    nixosConfigurations = {
      leonardn = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.leonardn = import ./home.nix;
          }
          {
            environment.systemPackages = [
              claude-code-nix.packages.x86_64-linux.default
            ];
          }
        ];
      };
    };
  };
}
