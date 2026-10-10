#!/bin/sh
# platform: host-agnostic
#   usage: tests/rust-toolchain-test.sh     each build host gets a Mavergreen/rust toolchain it can run
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL rust-toolchain: $1"; exit 1; }
[ -f "$ROOT/build/rust-toolchain.sh" ] || fail "no build/rust-toolchain.sh"
pick() { sh "$ROOT/build/rust-toolchain.sh" "$1" "$2"; }
[ "$(pick native x86_64)" = rust ] || fail "10.9 builds with the native toolchain"
[ "$(pick cross x86_64)" = rust ] || fail "a modern Intel Mac must get the x86_64 toolchain (rust); rust-cross is arm64-only and dies there with 'Bad CPU type'"
[ "$(pick cross arm64)" = rust-cross ] || fail "Apple Silicon builds with rust-cross"
if out="$(pick native arm64 2>&1)"; then fail "10.9 on arm64 does not exist, yet a toolchain was chosen: $out"; fi
if out="$(pick cross ppc 2>&1)"; then fail "an unknown arch must be refused, not given a toolchain: $out"; fi
echo "OK rust-toolchain"
