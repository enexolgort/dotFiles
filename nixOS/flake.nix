{
  description = "NixOS multimedia server (Jellyfin) with Doom Emacs — real machine + WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, ... }:
    let
      vars = import ./vars.nix;

      # Same username/timezone/paths/etc for both targets, but a distinct
      # hostname for WSL so it doesn't collide with the real machine on
      # your tailnet if you ever run both at once.
      wslVars = vars // { hostname = "${vars.hostname}-wsl"; };

      # NOTE: nixos-wsl deliberately does NOT follow our nixpkgs (see
      # inputs above) — its own Rust-based utility needs a newer Cargo
      # than the nixos-24.11 branch ships, so it needs its own pin.
      # useGlobalPkgs below still refers to *our* nixpkgs (24.11) for the
      # actual system/home-manager packages — only nixos-wsl's internal
      # build tooling uses its separate pin.
      mkHomeManagerModule = v: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { vars = v; };
        home-manager.users.${v.username} = import ./home.nix;
      };
    in {
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
        system = vars.system;
        specialArgs = { inherit vars; };
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule vars)
        ];
      };

      nixosConfigurations.${wslVars.hostname} = nixpkgs.lib.nixosSystem {
        system = wslVars.system;
        specialArgs = { vars = wslVars; inherit nixos-wsl; };
        modules = [
          ./wsl-configuration.nix
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule wslVars)
        ];
      };
    };
}
