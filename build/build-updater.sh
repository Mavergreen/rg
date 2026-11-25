#!/bin/sh
# platform: host-agnostic -- shipyard's build_updater.sh, with clang22 at shipyard's own pin
#   usage: build-updater.sh VERSION OUT-DIR     builds OUT-DIR/rg-updater.app, x86_64 at 10.9, and prints it
set -eu
[ $# -eq 2 ] || { echo "usage: build-updater.sh VERSION OUT-DIR" >&2; exit 2; }
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
# spec: updater/ICON-CREDIT.txt -- the generic icon on purpose, with its reason and its exit
exec sh "$SHIPYARD_SCRIPTS/build_updater.sh" --product rg --display-name "Mavericks ripgrep" \
  --confirm-title "Mavericks ripgrep updated" \
  --confirm-body "ripgrep for Mavericks in /usr/local/mavergreen/rg was updated." \
  --pubkey "$REPO_ROOT/updater/ed25519_key.pub" --version "$1" \
  --clang22-pin "$SHIPYARD_SCRIPTS/../components/clang22" --arch x86_64 \
  --generic-icon --log-prefix MavRipgrepUpdater --out-dir "$2"
