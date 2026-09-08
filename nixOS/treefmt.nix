# treefmt.nix — config for `nix fmt` / the `formatting` check in
# `nix flake check`. Scoped to the .nix files here in nixOS/.
{ pkgs, ... }:

{
  projectRootFile = "flake.nix";

  programs.alejandra.enable = true; # the standard Nix formatter
}
