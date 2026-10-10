#!/bin/sh
# platform: host-agnostic
#   usage: tests/fetch-test.sh     the ripgrep source is fetched only when crates.io vouches for it
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL fetch: $1"; exit 1; }
F="$ROOT/build/fetch-ripgrep.sh"
[ -f "$F" ] || fail "no build/fetch-ripgrep.sh"
U="$(tr -d ' \t\n' < "$ROOT/UPSTREAM_VERSION")"
t="$(mktemp -d "${TMPDIR:-/tmp}/rg-fetch-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT
crate="$t/ripgrep-$U.crate"
mkdir -p "$t/pkg/ripgrep-$U"
printf '[package]\nname = "ripgrep"\nversion = "%s"\n' "$U" > "$t/pkg/ripgrep-$U/Cargo.toml"
( cd "$t/pkg" && tar czf "$crate" "ripgrep-$U" ) || fail "could not build the crate fixture"
good="$(shasum -a 256 < "$crate" | cut -c1-64)"
bad="$(printf '%s' "$good" | tr '0123456789abcdef' '123456789abcdef0')"
entry() { printf '{"name":"ripgrep","vers":"%s","deps":[],"cksum":"%s","features":{},"yanked":false}\n' "$1" "$2"; }

unverified_fails() {
  entry 0.0.1 "$good" > "$t/index-bad"; entry "$U" "$bad" >> "$t/index-bad"
  if out="$(MAVERICKS_BUILD_ROOT="$t/b1" RG_INDEX_URL="file://$t/index-bad" RG_CRATE_URL="file://$crate" sh "$F" 2>&1)"; then
    fail "unverified_fails: a crate whose SHA-256 is not crates.io's was accepted: $out"
  fi
  if [ -n "$(find "$t/b1" -name Cargo.toml 2>/dev/null)" ]; then
    fail "unverified_fails: a rejected crate left a source tree behind"
  fi
}

absent_fails() {
  entry 0.0.1 "$good" > "$t/index-absent"
  if out="$(MAVERICKS_BUILD_ROOT="$t/b2" RG_INDEX_URL="file://$t/index-absent" RG_CRATE_URL="file://$crate" sh "$F" 2>&1)"; then
    fail "absent_fails: crates.io lists no $U, yet the fetch passed: $out"
  fi
  case "$out" in *"$U"*) : ;; *) fail "absent_fails: the refusal must name the missing version $U: $out" ;; esac
}

verified_extracts() {
  entry "$U" "$good" > "$t/index-good"
  src="$(MAVERICKS_BUILD_ROOT="$t/b3" RG_INDEX_URL="file://$t/index-good" RG_CRATE_URL="file://$crate" sh "$F")" \
    || fail "verified_extracts: a crate matching crates.io's SHA-256 was refused"
  grep -q "^version = \"$U\"\$" "$src/Cargo.toml" 2>/dev/null || fail "verified_extracts: $src/Cargo.toml is not version $U"
  case "$src" in "$t/b3"/*) : ;; *) fail "verified_extracts: the tree must live under MAVERICKS_BUILD_ROOT, not $src" ;; esac
}

extracts_afresh() {
  entry "$U" "$good" > "$t/index-good"
  src="$(MAVERICKS_BUILD_ROOT="$t/b5" RG_INDEX_URL="file://$t/index-good" RG_CRATE_URL="file://$crate" sh "$F")" \
    || fail "extracts_afresh: the first fetch was refused"
  echo stale > "$src/stale"
  src="$(MAVERICKS_BUILD_ROOT="$t/b5" RG_INDEX_URL="file://$t/index-good" RG_CRATE_URL="file://$crate" sh "$F")" \
    || fail "extracts_afresh: a second fetch from the verified cache was refused"
  [ ! -e "$src/stale" ] || fail "extracts_afresh: every fetch must extract afresh, so a patched or built tree never leaks into the next"
}

real_crate() {
  curl -fsS -o /dev/null https://index.crates.io/config.json 2>/dev/null || { echo "  (crates.io unreachable: real_crate not run)"; return 0; }
  src="$(MAVERICKS_BUILD_ROOT="$t/b4" sh "$F")" || fail "real_crate: the pinned ripgrep $U did not verify against crates.io"
  grep -q "^version = \"$U\"\$" "$src/Cargo.toml" || fail "real_crate: $src/Cargo.toml is not ripgrep $U"
  [ -f "$src/Cargo.lock" ] || fail "real_crate: the crate carries no Cargo.lock, so its dependencies are unpinned"
}

unverified_fails; absent_fails; verified_extracts; extracts_afresh; real_crate
echo "OK fetch"
