{
  description = "NixOS Konfiguration - leonardn";

  nixConfig = {
    extra-substituters = [ "https://niri.cachix.org" ];
    extra-trusted-public-keys = [ "niri.cachix.org-1:Wv0OmO7pzBacHgP5EQbJMHIiXKBw141h100ffWIbgv4=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, claude-code-nix, home-manager, mango, niri-flake, ... }:
  let
    homeManagerModules = [
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
  in {
    nixosConfigurations.leonardn = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self; };
      modules = [ ./hosts/leonardn ] ++ homeManagerModules;
    };

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self; };
      modules = [
        ./hosts/laptop
        mango.nixosModules.mango
        { home-manager.sharedModules = [ mango.hmModules.mango ]; }
        niri-flake.nixosModules.niri
      ] ++ homeManagerModules;
    };
  };
}
