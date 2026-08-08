# sops-nix

Nix-specific port of the ORESoftware SOPS environment contract. The security and dotenv behavior is intentionally the same as `flags-2-env-test/sops-just@933a239388449901bf8cccfd3db5c4d79fdec039`; only the toolchain wrapper changes.

This fixture has **no committed private age identity and no committed ciphertext**. Each verification run generates a fresh identity, exact dev/prod SOPS rules and synthetic ciphertext at runtime, exercises ignored decrypted files and the managed root `.env` symlink, then removes all runtime state.

## Nix-specific guarantees

- `nix run .#verify` executes the shared contract without entering a shell first;
- `nix develop --command bash scripts/assert.sh` exposes every required runtime (`sops`, `age`, Python, Git and shell/core utilities) from the pinned dev shell;
- the same flake-backed contract runs inside a clean container boundary;
- `nixpkgs` is pinned to an exact `nixos-unstable` commit rather than floating at test time.

## Shared security contract

- no private age identity in Git or logs;
- exact `env/enc/dev.env.enc` and `env/enc/prod.env.enc` creation rules;
- explicit SOPS dotenv input/output types plus filename override;
- no-identity decrypt failure;
- ignored `env/dec/**` with mode `0600`;
- unmanaged root `.env` refusal and managed relative symlink activation;
- Git ignore/index proof that plaintext is blocked while exactly the two approved ciphertext paths are allowlisted;
- cleanup removes runtime key/config/ciphertext/plaintext/symlink state.

All fixture values are synthetic.

## Run

```sh
nix run .#verify
nix develop --command bash scripts/assert.sh
docker build -t sops-nix-runtime-fixture .
docker run --rm sops-nix-runtime-fixture
```

Tracking: DEN-2919 / DEN-2636.
