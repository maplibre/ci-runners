{
  description = "MapLibre Forgejo server";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      # Use the deploy-rs build from nixpkgs so it comes from the binary cache.
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (final: prev: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              inherit (prev.deploy-rs) lib;
            };
          })
        ];
      };
    in
    {
      nixosConfigurations.forgejo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
      # The server builds its own system, so deploying works from any OS.
      deploy.nodes.forgejo = {
        hostname = "code.maplibre.org";
        sshUser = "root";
        remoteBuild = true;
        profiles.system = {
          user = "root";
          path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.forgejo;
        };
      };
    };
}
