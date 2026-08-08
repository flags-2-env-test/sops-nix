#!/usr/bin/env bash
# The contract every fixture in this matrix must satisfy, run identically on a
# host and inside a container. Sourced by CI and by `just verify` where just
# exists, so the two can never drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
ok(){ printf '  ok   %s\n' "$1"; }
no(){ printf '  FAIL %s\n' "$1"; fail=1; }

command -v sops >/dev/null || { echo "sops not installed"; exit 127; }

# 1. ciphertext is really encrypted, and names stay readable on purpose
grep -q 'ENC\[AES256_GCM' env/enc/dev.env.enc && ok "ciphertext is sops-encrypted" \
  || no "env/enc/dev.env.enc is not encrypted"
grep -q '^API_TOKEN=ENC\[' env/enc/dev.env.enc && ok "variable NAMES readable, values encrypted" \
  || no "expected API_TOKEN to be present-but-encrypted"
grep -q 'super-secret' env/enc/dev.env.enc && no "plaintext value leaked into ciphertext" \
  || ok "no plaintext value in ciphertext"

# 2. decrypt round-trips exactly, including the awkward values
out=$(sops decrypt --input-type dotenv --output-type dotenv env/enc/dev.env.enc)
grep -qx 'API_TOKEN=super-secret-value' <<<"$out" && ok "simple value round-trips" \
  || no "simple value did not round-trip"
grep -qx 'URL=postgres://u:p@h:5432/db?a=1&b=2' <<<"$out" && ok "value containing = and & survives" \
  || no "URL value was mangled"

# 3. the quoting rule every consumer must agree on: a quoted value loses its
#    quotes and \n becomes a real newline. docker --env-file and
#    kubectl --from-env-file both get this wrong natively.
python3 - <<'PY' && ok "quoted PEM normalises to real newlines" || no "PEM normalisation wrong"
import subprocess,sys
raw=subprocess.run(["sops","decrypt","--input-type","dotenv","--output-type","dotenv",
                    "env/enc/dev.env.enc"],capture_output=True,text=True).stdout
line=[l for l in raw.splitlines() if l.startswith("PEM=")][0][4:]
v=line[1:-1].encode().decode("unicode_escape") if line[:1]=='"' else line
sys.exit(0 if v.startswith("-----BEGIN") and "\n" in v and '"' not in v else 1)
PY

# 4. no plaintext may be tracked by git
if git rev-parse --git-dir >/dev/null 2>&1; then
  bad=$(git ls-files | grep -E '(^|/)\.env$|(^|/)env/dec/' || true)
  [ -z "$bad" ] && ok "no plaintext env tracked" || no "tracked plaintext: $bad"
fi

[ "$fail" -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
