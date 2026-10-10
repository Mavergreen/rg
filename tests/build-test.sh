#!/bin/sh
# platform: macOS-only -- file and lipo read the Mach-O, and only a Mac runs it
#   usage: tests/build-test.sh     the built rg is an x86_64 executable of the pinned upstream, with its
#          generated man page and completions beside it
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$ROOT"; export REPO_ROOT
fail() { echo "FAIL build: $1"; exit 1; }
[ -f "$ROOT/build/build.sh" ] || fail "no build/build.sh"
grep -q "^unset SDKROOT RUSTFLAGS CARGO_ENCODED_RUSTFLAGS\$" "$ROOT/build/build.sh" \
  || fail "build.sh must clear RUSTFLAGS and CARGO_ENCODED_RUSTFLAGS: cargo prefers either over the per-target flags that carry the 10.9 SDK"
. "$ROOT/build/versions.sh"
OUT="$WORK/out"
RG="$OUT/bin/rg"
[ -x "$RG" ] || { echo "SKIP build: not built -- run build/build.sh"; exit 77; }

file "$RG" | grep -q 'Mach-O 64-bit executable x86_64' || fail "$RG is not a thin x86_64 executable: $(file "$RG")"
[ "$(lipo -info "$RG" | sed -n 's/.*architecture: //p')" = x86_64 ] || fail "$RG must carry exactly one slice, x86_64: $(lipo -info "$RG")"

man="$OUT/share/man/man1/rg.1"
[ -s "$man" ] || fail "no generated man page at $man"
grep -q '^\.TH RG 1' "$man" || fail "$man is not rg's man page"
grep -q "$RG_VERSION" "$man" || fail "$man does not name ripgrep $RG_VERSION"
for c in share/bash-completion/completions/rg share/zsh/site-functions/_rg share/fish/vendor_completions.d/rg.fish; do
  [ -s "$OUT/$c" ] || fail "no generated completion at $OUT/$c"
done
grep -q 'rg' "$OUT/share/zsh/site-functions/_rg" || fail "the zsh completion does not complete rg"

if [ "$(uname -m)" != x86_64 ]; then
  echo "OK build (static checks; the x86_64 rg runs on Mac OS X 10.9 in release.yml's vm-test job, never under Rosetta)"
  exit 0
fi
ver="$("$RG" --version)" || fail "$RG --version did not run"
first="$(printf '%s\n' "$ver" | sed -n 1p)"
case "$first" in "ripgrep $RG_VERSION"|"ripgrep $RG_VERSION "*) : ;; *) fail "rg --version says '$first', not ripgrep $RG_VERSION" ;; esac
case "$ver" in *"+pcre2"*) fail "rg was built with PCRE2; v1 ships default features only" ;; esac
t="$(mktemp -d "${TMPDIR:-/tmp}/rg-build-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT
printf 'needle\nhay\n' > "$t/input.txt"
[ "$("$RG" --no-config -c needle "$t/input.txt")" = 1 ] || fail "rg did not find the one matching line"
echo "OK build"
