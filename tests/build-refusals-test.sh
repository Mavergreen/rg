#!/bin/sh
# platform: macOS-only -- runs build/build.sh, which builds with macOS's toolchain and SDK
#   usage: tests/build-refusals-test.sh     build.sh stops, and keeps the previous rg, when it cannot build
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$ROOT"; export REPO_ROOT
fail() { echo "FAIL build-refusals: $1"; exit 1; }
. "$ROOT/build/versions.sh"
RG="$WORK/out/bin/rg"
[ -x "$RG" ] || { echo "SKIP build-refusals: not built -- run build/build.sh"; exit 77; }

sp="$(mktemp -d "${TMPDIR:-/tmp}/rg build-refusals.XXXXXX")"; trap 'rm -rf "$sp"' EXIT
ln -s "$(dirname "$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")")" "$sp/sdk cache"
rc=0; out="$(MAVERICKS_SDK_CACHE="$sp/sdk cache" sh "$ROOT/build/build.sh" 2>&1)" || rc=$?
[ "$rc" -ne 0 ] || fail "build.sh accepted an SDK path with a space, which cargo would split inside the per-target flags"
case "$out" in *"contains whitespace"*) : ;; *) fail "build.sh must refuse an SDK path with a space before cargo runs, saying so: $(printf "%s" "$out" | tail -3)" ;; esac
[ -x "$RG" ] || fail "a refused build must leave the previous rg in place"

# platform: cargo refuses CARGO_BUILD_JOBS=0 before compiling anything
rc=0; out="$(CARGO_BUILD_JOBS=0 sh "$ROOT/build/build.sh" 2>&1)" || rc=$?
[ "$rc" -ne 0 ] || fail "build.sh carried on after cargo failed (10.9 sh ignores set -e for a failing subshell): $(printf "%s" "$out" | tail -3)"
case "$out" in *">> built"*) fail "build.sh reported a build after cargo failed" ;; esac
[ -x "$RG" ] || fail "a failed cargo build must leave the previous rg in place"
echo "OK build-refusals"
