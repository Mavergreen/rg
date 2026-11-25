#!/bin/sh
# platform: host-agnostic
#   usage: tests/rust-toolchain-test.sh     each build host gets a Mavergreen/rust toolchain it can run
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL rust-toolchain: $1"; exit 1; }
[ -f "$ROOT/build/rust-toolchain.sh" ] || fail "no build/rust-toolchain.sh"
pick() { sh "$ROOT/build/rust-toolchain.sh" "$1" "$2"; }
[ "$(pick Linux x86_64)" = cargo-env ] || fail "x86_64 Linux builds with shipyard's cargo-env.sh and the pinned rust's Linux toolchain"
[ "$(pick Darwin x86_64)" = cargo-env ] || fail "10.9 and a modern Intel Mac build with cargo-env.sh and the pinned rust; rust-cross is arm64-only and dies there with 'Bad CPU type'"
[ "$(pick Darwin arm64)" = rust-cross ] || fail "Apple Silicon builds with rust-cross"
if out="$(pick Linux aarch64 2>&1)"; then fail "the rust release has no arm64 Linux toolchain, yet one was chosen: $out"; fi
if out="$(pick Darwin ppc 2>&1)"; then fail "an unknown arch must be refused, not given a toolchain: $out"; fi
echo "OK rust-toolchain"
