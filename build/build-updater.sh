#!/bin/sh
# platform: macOS-only -- builds a Cocoa app with Apple's toolchain
#   usage: build-updater.sh     prints the built rg-updater.app path
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
B="$WORK/updater"
# platform: /usr/local/mavergreen/bin reaches PATH only through a login shell's paths.d
SYCM="$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)"
# platform: a pkgsrc or Homebrew clang can precede /usr/bin on PATH, and RequireAppleClang refuses it
OBJC=/usr/bin/clang "$SYCM" -S "$REPO_ROOT" -B "$B" -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_TOOLCHAIN_FILE="$(dirname "$SHIPYARD_SCRIPTS")/MavericksToolchain.cmake" >&2
"$SYCM" --build "$B" >&2
app="$B/$SHORT-updater.app"
[ -d "$app" ] || { echo "build-updater: no $SHORT-updater.app under $B" >&2; exit 1; }
printf '%s\n' "$app"
