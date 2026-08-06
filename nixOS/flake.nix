{
  description = "NixOS multimedia server (Jellyfin) with Doom Emacs — real machine + WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

      # NOTE: nixos-wsl's own nixpkgs input isn't following ours, but its
      # NixOS module still builds nixos-wsl-utils against *our* nixpkgs
      # (that's just how nixosSystem's pkgs resolution works, regardless
      # of the flake input's own separate pin) — so the thing that
      # actually matters for that build to succeed is that OUR nixpkgs
      # (below) is new enough. We were on nixos-25.11 (EOL, Cargo too old
      # for nixos-wsl-utils' edition2024 requirement); nixos-25.11 fixes
      # this at the root.
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
