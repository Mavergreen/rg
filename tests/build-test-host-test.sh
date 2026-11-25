#!/bin/sh
# platform: macOS-only -- clang links a stand-in x86_64 rg, and build-test.sh reads it with file and lipo
#   usage: tests/build-test-host-test.sh     build-test runs the shipped rg only on an x86_64 Mac; on
#          Apple Silicon it never reaches for Rosetta, and on Linux it never tries
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/msc.sh"
fail() { echo "FAIL build-test-host: $1"; exit 1; }
command -v clang >/dev/null 2>&1 || fail "no clang to build the stand-in rg"
t="$(mktemp -d "${TMPDIR:-/tmp}/rg-host-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT
U="$(tr -d ' \t\n' < "$ROOT/UPSTREAM_VERSION")"
O="$t/root/$(basename "$ROOT")/out"
mkdir -p "$O/bin" "$O/share/man/man1" "$O/share/bash-completion/completions" "$O/share/zsh/site-functions" \
  "$O/share/fish/vendor_completions.d" "$t/bin"
printf '#include <stdio.h>\nint main(void) { FILE *f = fopen("%s/ran", "w"); if (f) fclose(f); return 1; }\n' "$t" > "$t/rg.c"
clang -arch x86_64 -isysroot "$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")" -mmacosx-version-min=10.9 "$t/rg.c" -o "$O/bin/rg"
printf '.TH RG 1 2026-01-01 "%s"\n' "$U" > "$O/share/man/man1/rg.1"
printf '#compdef rg\n' > "$O/share/zsh/site-functions/_rg"
printf 'complete -F _rg rg\n' > "$O/share/bash-completion/completions/rg"
printf 'complete -c rg\n' > "$O/share/fish/vendor_completions.d/rg.fish"
host() {  # $1 = uname -s, $2 = uname -m
  printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; *) echo %s ;; esac\n' "$1" "$2" > "$t/bin/uname"; chmod +x "$t/bin/uname"
  PATH="$t/bin:$PATH" MAVERICKS_BUILD_ROOT="$t/root" sh "$ROOT/tests/build-test.sh" > "$t/out" 2>&1
}

rc=0; host Linux x86_64 || rc=$?
[ ! -e "$t/ran" ] || fail "on Linux build-test must not execute the Mach-O rg: Linux cannot, and release.yml's vm-test job runs it on 10.9"
[ "$rc" = 0 ] || fail "on Linux build-test must pass the checks it can make (exit $rc: $(cat "$t/out"))"
grep -q 'vm-test' "$t/out" || fail "on Linux build-test must say where the x86_64 rg runs instead (got: $(cat "$t/out"))"

rc=0; host Darwin arm64 || rc=$?
[ ! -e "$t/ran" ] || fail "on arm64 build-test must not execute the x86_64 rg: that would be Rosetta, and release.yml's vm-test job runs it on 10.9"
[ "$rc" = 0 ] || fail "on arm64 build-test must pass the checks it can make (exit $rc: $(cat "$t/out"))"
grep -q 'vm-test' "$t/out" || fail "on arm64 build-test must say where the x86_64 rg runs instead (got: $(cat "$t/out"))"

mv "$O/share/man/man1/rg.1" "$t/rg.1"
rc=0; host Darwin arm64 || rc=$?
mv "$t/rg.1" "$O/share/man/man1/rg.1"
[ "$rc" != 0 ] || fail "on arm64 build-test must still check the generated man page"

rc=0; host Darwin x86_64 || rc=$?
[ -e "$t/ran" ] || fail "on x86_64 build-test must execute the shipped rg"
[ "$rc" != 0 ] || fail "on x86_64 build-test must fail an rg that prints no version"
echo "OK build-test-host"
