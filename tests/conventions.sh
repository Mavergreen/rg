#!/bin/sh
# platform: host-agnostic
#   usage: tests/conventions.sh     the family-conventions gate accepts this repo, and actually ran
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL conventions: $1"; exit 1; }
[ -f build/msc.sh ] || fail "no build/msc.sh -- nothing can locate shipyard's scripts"
. build/msc.sh
rc=0; out="$(sh "$SHIPYARD_SCRIPTS/check-family-conventions.sh" 2>&1)" || rc=$?
printf '%s\n' "$out"
[ "$rc" -eq 0 ] || fail "the family-conventions gate rejects this repo (exit $rc)"
case "$out" in *"not a product repo"*) fail "the gate checked nothing: it only checks a repo with .github/workflows/release.yml" ;; esac
echo "OK conventions"
