{
  description = "vps — single-host NixOS config for a Hostinger VPS (Obsidian sync + git server + local AI + n8n + Tailscale + Docker, all tailnet-only)";

  inputs = {
    # Tracking 26.05 (not yet stable at the time of writing — this
    # follows the same "pin ahead" convention the inspiration repo used
    # for its own vps host). If the nixos-26.05 branch doesn't exist yet
    # on your rebuild date, fall back to nixos-unstable until it does.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, treefmt-nix, ... }:
    let
      lib = nixpkgs.lib;
      defaults = import ./hosts/defaults.nix;
      hostVars = import ./hosts/vps/vars.nix;
      vars = defaults // hostVars;

      system = vars.system;
      pkgs = nixpkgs.legacyPackages.${system};
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatting = treefmtEval.config.build.check self;

      nixosConfigurations.vps = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit vars; };
        modules = [
          ./configuration.nix
          ./hosts/vps/hardware-configuration.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit vars; };
            home-manager.users.${vars.username}.imports = [ ./home.nix ];
          }
        ];
      };
    };
}
