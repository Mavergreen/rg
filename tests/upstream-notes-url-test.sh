#!/bin/sh
# platform: host-agnostic
#   usage: tests/upstream-notes-url-test.sh     a new upstream's notes link names that exact release
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL upstream-notes-url: $1"; exit 1; }
H="$ROOT/build/upstream-release-notes-url.sh"
[ -f "$H" ] || fail "build/upstream-release-notes-url.sh missing (conventions check 11: a new upstream links upstream's notes)"
U="$(tr -d ' \t\n' < "$ROOT/UPSTREAM_VERSION")"
out="$(sh "$H" "$U")"
[ "$out" = "https://github.com/BurntSushi/ripgrep/releases/tag/$U" ] || fail "want ripgrep's release page for $U, got: $out"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] || fail "upstream-notes.sh accepts exactly one line"
if sh "$H" 2>/dev/null; then fail "no argument must be a usage error"; fi
echo "OK upstream-notes-url"
