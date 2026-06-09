{
  description = "Spokane Mountaineers Salesforce dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        sf = pkgs.callPackage ./nix/sf-cli.nix { };
        default = self.packages.${pkgs.system}.sf;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs      # node, npm, npx — tracks current LTS (24.x)
            pkgs.gettext     # envsubst — used by scripts/deploy-authproviders.sh
            self.packages.${pkgs.system}.sf
          ];
        };
      });
    };
  }
