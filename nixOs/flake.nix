{
  description = "NixOS multimedia server (Jellyfin) with Doom Emacs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      vars = import ./vars.nix;
    in {
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
        system = vars.system;
        specialArgs = { inherit vars; };
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit vars; };
            home-manager.users.${vars.username} = import ./home.nix;
          }
        ];
      };
    };
}
