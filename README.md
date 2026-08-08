# sops-nix

sops environment fixture for the toolchain combination: **sops + nix (no just)**.

Part of a matrix that proves the sops `env/enc` ↔ `env/dec` pattern behaves
identically across toolchains **and** on both sides of a container boundary.
Same contract in every fixture (`scripts/assert.sh`); only the surrounding
tooling differs.

## Why the container half matters

Every defect this pattern has actually shipped was invisible from one side:

| Defect | Visible from |
|---|---|
| `dd … status=none` is GNU-only, so the secure overwrite silently no-opped | Linux only |
| `python3` missing from the nix devshell | inside `nix develop` only |
| k8s Secret named from `basename(pwd)` → `w-local` under a `/w` mount | container only |
| `sops exec-env` needs `/bin/sh`, so it cannot run on distroless | container only |

So each fixture asserts on the host **and** in Docker, and CI runs both.

## Run it

```sh
nix run .#verify                 # host
docker build -t sops-nix . && docker run --rm sops-nix   # container
```

## The committed key is intentional

`age.key` is a **throwaway** private key, committed so CI can decrypt with zero
secrets configured. Every value it protects is fake. It exists to make the e2e
real; never reuse it. In a production repo the private key is never committed —
see the recipient-roster model in `.sops.yaml`.
