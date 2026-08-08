# Expected behaviour

`scripts/assert.sh` exits 0 and prints `PASS`, having verified:

1. `env/enc/dev.env.enc` is genuinely sops-encrypted (`ENC[AES256_GCM`).
2. Variable **names** stay readable while values are encrypted — deliberate, so
   a PR diff shows *which* variable changed without leaking the value.
3. No plaintext value appears anywhere in the ciphertext.
4. A simple value round-trips exactly.
5. `URL=postgres://u:p@h:5432/db?a=1&b=2` survives — split on the FIRST `=` only.
6. A double-quoted PEM normalises to real newlines with the surrounding quotes
   stripped. `docker --env-file` and `kubectl --from-env-file` both get this
   wrong natively, which is why the value is normalised rather than passed raw.
7. Git tracks no plaintext env file.

Identical output is required on the host and inside the container. A difference
between the two is the failure this fixture exists to catch.
