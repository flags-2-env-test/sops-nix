{
  description = "sops env fixture — nix half of the toolchain matrix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAll (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            # python3 is NOT optional: the dotenv normalisation in
            # scripts/assert.sh needs it. Omitting it is a real defect this
            # matrix exists to catch.
            packages = with pkgs; [ sops age python3 bash git ];
          };
        });
      # `nix run .#verify` must work with no devshell entered.
      apps = forAll (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          verify = {
            type = "app";
            program = toString (pkgs.writeShellScript "verify" ''
              export PATH=${pkgs.lib.makeBinPath (with pkgs; [ sops age python3 git coreutils gnugrep ])}:$PATH
              export SOPS_AGE_KEY_FILE=age.key
              exec ./scripts/assert.sh
            '');
          };
        });
    };
}
