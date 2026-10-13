{
  description = "MapLibre ctcache server and deployment tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        ctcache = pkgs.callPackage ./package.nix { };
        default = self.packages.${system}.ctcache;
      };
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          opentofu
          just
          openssh
          openssl
          awscli2
          gh
          jq
          curl
          python3
          shellcheck
          actionlint
          nixfmt
        ];
      };
      nixosConfigurations.ctcache = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    };
}
