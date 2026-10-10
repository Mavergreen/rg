#!/bin/sh
# platform: host-agnostic
#   usage: tests/check-release-args-test.sh     the real-10.9 release check refuses bad input before it
#          installs anything
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL check-release-args: $1"; exit 1; }
S="$ROOT/build/check-release-on-10.9.sh"
[ -f "$S" ] || fail "build/check-release-on-10.9.sh missing"
rc=0; out="$(sh "$S" 2>&1)" || rc=$?
[ "$rc" = 2 ] || fail "no argument: exit 2 (usage), got $rc"
case "$out" in *usage*) : ;; *) fail "no argument must print usage: $out" ;; esac
rc=0; out="$(MAVERICKS_CHECK_OS=15.7 sh "$S" 15.2.0-mavericks.1 2>&1)" || rc=$?
[ "$rc" = 2 ] || fail "off 10.9: exit 2 before touching anything, got $rc"
case "$out" in *10.9*) : ;; *) fail "off 10.9 the refusal must say it needs 10.9: $out" ;; esac
t="$(mktemp -d "${TMPDIR:-/tmp}/check-release.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/rel"
printf '#!/bin/sh\necho called > "%s/sudo-called"\n' "$t" > "$t/bin/sudo"; chmod +x "$t/bin/sudo"
echo pkg > "$t/rel/rg-15.2.0-mavericks.1.pkg"
echo "0000  rg-other.pkg" > "$t/rel/SHA256SUMS"
rc=0; out="$(PATH="$t/bin:$PATH" MAVERICKS_CHECK_OS=10.9.5 MAVERICKS_RELEASE_BASE="file://$t/rel" sh "$S" 15.2.0-mavericks.1 2>&1)" || rc=$?
[ "$rc" != 0 ] || fail "a pkg that SHA256SUMS does not list must fail the check: $out"
[ ! -f "$t/sudo-called" ] || fail "an unverified pkg must never reach sudo installer"
echo "OK check-release-args"
