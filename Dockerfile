FROM nixos/nix:2.35.1-amd64

ARG NIXPKGS_REF=b7c2ada94fe99c15b0dbcf4d11fd7850b957a436

WORKDIR /fixture
COPY . .

# The Docker build context intentionally excludes caller Git metadata. Use the
# same exact nixpkgs pin as flake.nix to supply Git only for initializing a tiny
# local repository; the resulting image does not depend on an OS package manager.
RUN nix \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      --option sandbox false \
      shell "github:NixOS/nixpkgs/${NIXPKGS_REF}#git" \
      --command sh -c 'git init -q \
        && git config user.name fixture \
        && git config user.email fixture@example.invalid \
        && git add -A \
        && git commit -qm fixture'

CMD ["nix", "--extra-experimental-features", "nix-command", "--extra-experimental-features", "flakes", "--option", "sandbox", "false", "run", "--no-write-lock-file", ".#verify"]
