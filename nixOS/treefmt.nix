# treefmt.nix — config for `nix fmt` / the `formatting` check in
# `nix flake check`. Scoped to the .nix files here in nixOS/ (where this
# file and flake.nix both live) — shell scripts in ../scripts/ are
# linted separately by shellcheck in CI rather than auto-formatted here,
# since treefmt's tree root is this directory, not the repo root.
{ pkgs, ... }:

{
  projectRootFile = "flake.nix";

  programs.alejandra.enable = true; # the standard Nix formatter
}
