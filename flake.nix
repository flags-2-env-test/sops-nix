{
  description = "Runtime-generated SOPS dotenv fixture — Nix wrapper";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/b7c2ada94fe99c15b0dbcf4d11fd7850b957a436";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packagesFor = system:
        let pkgs = import nixpkgs { inherit system; };
        in with pkgs; [
          age
          bash
          coreutils
          findutils
          git
          gnugrep
          python3
          sops
        ];
    in
    {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = packagesFor system;
          };
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          path = pkgs.lib.makeBinPath (packagesFor system);
          verify = pkgs.writeShellScript "sops-nix-verify" ''
            set -euo pipefail
            export PATH=${path}:$PATH
            exec ${pkgs.bash}/bin/bash ./scripts/assert.sh
          '';
        in {
          verify = {
            type = "app";
            program = toString verify;
          };
          default = {
            type = "app";
            program = toString verify;
          };
        });
    };
}
