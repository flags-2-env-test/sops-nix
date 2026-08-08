# Expected behavior

The Nix wrapper must not change the SOPS security contract established by `flags-2-env-test/sops-just@933a239388449901bf8cccfd3db5c4d79fdec039`.

A passing run proves:

1. `nix run .#verify` supplies the runtime tools and executes the shared assertion contract.
2. `nix develop --command bash scripts/assert.sh` supplies the same required tools from the pinned dev shell.
3. A fresh age identity is generated at runtime with mode `0600` and is never logged or tracked.
4. Runtime SOPS rules select exactly `env/enc/dev.env.enc` and `env/enc/prod.env.enc`.
5. `.env.enc` operations force dotenv types and use filename override for encryption.
6. Synthetic plaintext does not appear in ciphertext; decryption without the generated identity fails.
7. Dev and prod values round-trip exactly and decrypted files remain `0600` under ignored `env/dec/`.
8. An unmanaged root `.env` is refused; the managed root `.env` is a relative symlink to an approved decrypted target.
9. Plaintext dotenv state is ignored while exactly the two canonical ciphertext paths are allowlisted by normal Git staging.
10. The committed tree contains no private age identity and no tracked plaintext dotenv-like path.
11. Cleanup removes runtime identity, SOPS config, ciphertext, decrypted files and root symlink.
12. A clean container running the flake-backed verify app satisfies the same assertions.
13. `nixpkgs` is pinned to an exact commit so tool resolution does not float between runs.
