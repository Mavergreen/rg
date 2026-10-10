#!/bin/sh
# platform: macOS-only -- shipyard's compat guard reads Mach-O with otool, nm and lipo
#   usage: gate.sh <binary>...     fails unless every binary is 10.9-safe
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAVERICKS_ROOT="$REPO_ROOT"; export MAVERICKS_ROOT
. "$REPO_ROOT/build/msc.sh"
# platform: Mavergreen/rust's wrapper force-loads macports-legacy-support into every 10.9 link, and
#           std calls clock_gettime and CCRandomGenerateBytes, which 10.9 lacks; the shim must define both
MAVERICKS_REQUIRE_DEFINED_SYMBOLS='_clock_gettime _CCRandomGenerateBytes' MAVERICKS_ALLOW_ARCHS=x86_64 \
  MAVERICKS_DEVIATIONS_ROOT="$REPO_ROOT" exec sh "$SHIPYARD_SCRIPTS/assert_binary_compatible.sh" "$@"
