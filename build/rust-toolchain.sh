#!/bin/sh
# platform: host-agnostic
#   usage: rust-toolchain.sh <os> <arch>     prints how rg's cargo environment is made here
#          <os> and <arch> are `uname -s` and `uname -m`. cargo-env: shipyard's cargo-env.sh with the
#          pinned rust, on x86_64 Linux, 10.9 and an Intel Mac; rust-cross: the pinned rust-cross pkg,
#          which runs on Apple Silicon only.
set -eu
case "${1:-}:${2:-}" in
  Linux:x86_64|Darwin:x86_64) echo cargo-env ;;
  Darwin:arm64) echo rust-cross ;;
  *) echo "rust-toolchain: no Mavergreen/rust toolchain runs on '${1:-}', arch '${2:-}'" >&2; exit 1 ;;
esac
