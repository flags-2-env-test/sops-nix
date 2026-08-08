#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

ok() {
  printf '  ok   %s\n' "$1"
}

fail() {
  printf '  FAIL %s\n' "$1" >&2
  exit 1
}

for cmd in sops age-keygen git python3; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command missing: $cmd"
done

runtime="$repo_root/.fixture-runtime"
config="$repo_root/.fixture.sops.yaml"

# Fail closed rather than overwrite any state a developer already has.
for path in .env "$runtime" "$config" env/dec env/enc; do
  if [[ -e "$path" || -L "$path" ]]; then
    fail "refusing pre-existing runtime path: $path"
  fi
done

cleanup() {
  rm -f -- .env "$config"
  rm -rf -- "$runtime" env/dec env/enc
}
trap cleanup EXIT HUP INT TERM

umask 077
mkdir -p "$runtime/empty-home" "$runtime/empty-xdg" env/enc env/dec
identity="$runtime/age.key"
age-keygen -o "$identity" >/dev/null 2>&1
chmod 600 "$identity"
recipient="$(age-keygen -y "$identity")"
[[ "$recipient" == age1* ]] || fail "age recipient derivation failed"
ok "ephemeral age identity generated without logging it"

cat > "$config" <<EOF
creation_rules:
  - path_regex: '^env/enc/dev\\.env\\.enc$'
    age:
      - '$recipient'
  - path_regex: '^env/enc/prod\\.env\\.enc$'
    age:
      - '$recipient'
EOF
chmod 600 "$config"

private_marker='AGE-SECRET''-KEY-'
if git grep -I -F "$private_marker" -- . >/dev/null 2>&1; then
  fail "a private age identity is present in tracked content"
fi
ok "tracked content contains no private age identity"

if ! git ls-files -z | python3 -c '
import sys
paths = [p.decode("utf-8", "surrogateescape") for p in sys.stdin.buffer.read().split(b"\0") if p]
approved = {"env/enc/dev.env.enc", "env/enc/prod.env.enc"}
bad = []
for path in paths:
    name = path.rsplit("/", 1)[-1]
    dotenv_like = name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name
    if dotenv_like and path not in approved:
        bad.append(path)
raise SystemExit(1 if bad else 0)
'; then
  fail "tracked plaintext dotenv-like path exists"
fi
ok "tracked tree has no plaintext dotenv-like path"

encrypt_fixture() {
  local env_name="$1"
  local source="fixtures/${env_name}.fixture.dotenv"
  local target="env/enc/${env_name}.env.enc"
  local tmp="$runtime/${env_name}.env.enc.tmp"

  SOPS_CONFIG="$config" sops encrypt \
    --filename-override "$target" \
    --input-type dotenv \
    --output-type dotenv \
    "$source" > "$tmp"
  chmod 600 "$tmp"
  mv -- "$tmp" "$target"
}

encrypt_fixture dev
encrypt_fixture prod

for env_name in dev prod; do
  cipher="env/enc/${env_name}.env.enc"
  grep -q '^API_TOKEN=ENC\[' "$cipher" || fail "$env_name ciphertext does not encrypt values as dotenv"
  grep -q 'ENC\[AES256_GCM' "$cipher" || fail "$env_name ciphertext lacks SOPS payload"
  if grep -Fq "synthetic-${env_name}-token" "$cipher"; then
    fail "$env_name plaintext leaked into ciphertext"
  fi
done
ok "dev/prod ciphertext generated at canonical paths"

# A fresh environment without the generated identity must not be able to decrypt.
if env \
  -u SOPS_AGE_KEY_FILE \
  -u SOPS_AGE_KEY \
  HOME="$runtime/empty-home" \
  XDG_CONFIG_HOME="$runtime/empty-xdg" \
  sops decrypt --input-type dotenv --output-type dotenv env/enc/dev.env.enc \
  >/dev/null 2>&1; then
  fail "ciphertext decrypted without the runtime identity"
fi
ok "no-identity decrypt fails closed"

decrypt_fixture() {
  local env_name="$1"
  local source="env/enc/${env_name}.env.enc"
  local target="env/dec/${env_name}.env"
  local tmp="$runtime/${env_name}.decrypted.tmp"

  SOPS_AGE_KEY_FILE="$identity" sops decrypt \
    --input-type dotenv \
    --output-type dotenv \
    "$source" > "$tmp"
  chmod 600 "$tmp"
  mv -- "$tmp" "$target"
}

decrypt_fixture dev
decrypt_fixture prod

python3 - <<'PY'
from pathlib import Path
import stat


def parse(path: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in Path(path).read_text().splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result

for name in ("dev", "prod"):
    expected = parse(f"fixtures/{name}.fixture.dotenv")
    actual = parse(f"env/dec/{name}.env")
    if expected != actual:
        raise SystemExit(f"{name} decrypted dotenv did not round-trip")
    mode = stat.S_IMODE(Path(f"env/dec/{name}.env").stat().st_mode)
    if mode != 0o600:
        raise SystemExit(f"{name} decrypted mode is {oct(mode)}, expected 0o600")

identity_mode = stat.S_IMODE(Path(".fixture-runtime/age.key").stat().st_mode)
if identity_mode != 0o600:
    raise SystemExit(f"identity mode is {oct(identity_mode)}, expected 0o600")
PY
ok "decrypted values round-trip and private files are mode 0600"

activate_env() {
  local env_name="$1"
  local target="env/dec/${env_name}.env"
  local link_tmp="$runtime/root-env-link"

  [[ "$env_name" == dev || "$env_name" == prod ]] || return 1
  [[ -f "$target" ]] || return 1

  if [[ -e .env || -L .env ]]; then
    [[ -L .env ]] || return 1
    current="$(readlink .env)"
    [[ "$current" == env/dec/dev.env || "$current" == env/dec/prod.env ]] || return 1
  fi

  rm -f -- "$link_tmp"
  ln -s "$target" "$link_tmp"
  mv -f -- "$link_tmp" .env
}

printf 'UNMANAGED=synthetic-only\n' > .env
if activate_env dev; then
  fail "activation overwrote an unmanaged root .env"
fi
rm -f -- .env
ok "unmanaged root .env is refused"

activate_env dev || fail "managed dev activation failed"
[[ -L .env ]] || fail "root .env is not a symlink"
[[ "$(readlink .env)" == "env/dec/dev.env" ]] || fail "root .env symlink is not relative/canonical"
ok "root .env is a managed relative symlink"

git check-ignore -q -- .env || fail "root .env is not ignored"
git check-ignore -q -- env/dec/dev.env || fail "decrypted dev dotenv is not ignored"
git check-ignore -q --no-index -- nested/.env.local || fail "nested .env.local is not ignored"
if git check-ignore -q -- env/enc/dev.env.enc; then
  fail "approved dev ciphertext path is ignored"
fi
if git check-ignore -q -- env/enc/prod.env.enc; then
  fail "approved prod ciphertext path is ignored"
fi
ok "ignore boundary blocks plaintext and allowlists only canonical ciphertext"

index="$runtime/test.index"
GIT_INDEX_FILE="$index" git read-tree HEAD
if GIT_INDEX_FILE="$index" git add .env env/dec/dev.env >/dev/null 2>&1; then
  fail "normal git add accepted ignored plaintext dotenv state"
fi
GIT_INDEX_FILE="$index" git add env/enc/dev.env.enc env/enc/prod.env.enc
mapfile -t staged_cipher < <(GIT_INDEX_FILE="$index" git ls-files 'env/enc/*')
[[ ${#staged_cipher[@]} -eq 2 ]] || fail "temporary index did not admit exactly two ciphertext paths"
[[ "${staged_cipher[0]}" == "env/enc/dev.env.enc" ]] || fail "unexpected first ciphertext path"
[[ "${staged_cipher[1]}" == "env/enc/prod.env.enc" ]] || fail "unexpected second ciphertext path"
ok "normal Git staging rejects plaintext and admits exactly dev/prod ciphertext"

printf 'PASS: runtime-generated SOPS contract\n'
