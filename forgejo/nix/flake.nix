{
  description = "MapLibre Forgejo server";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs =
    { nixpkgs, ... }:
    {
      nixosConfigurations.forgejo = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./configuration.nix ];
      };
    };
}
