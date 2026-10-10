#!/bin/sh
# platform: macOS-only -- otool, nm and clang read and write Mach-O
#   usage: tests/compat-test.sh     rg is proven 10.9-safe, and the gate refuses a binary that is not
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$ROOT"; export REPO_ROOT
fail() { echo "FAIL compat: $1"; exit 1; }
G="$ROOT/build/gate.sh"
[ -f "$G" ] || fail "no build/gate.sh"
. "$ROOT/build/versions.sh"
RG="$WORK/out/bin/rg"
[ -x "$RG" ] || { echo "SKIP compat: not built -- run build/build.sh"; exit 77; }
t="$(mktemp -d "${TMPDIR:-/tmp}/rg-compat-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT

floor_is_10_9() {
  floors="$(otool -l "$RG" | awk '/LC_VERSION_MIN_MACOSX/{v=1} /LC_BUILD_VERSION/{b=1}
    v && $1 == "version" {print $2; v=0} b && $1 == "minos" {print $2; b=0}')"
  [ -n "$floors" ] || fail "floor_is_10_9: rg records no deployment target at all"
  for f in $floors; do
    case "$f" in 10.[0-9]|10.[0-9].*) : ;; *) fail "floor_is_10_9: rg records minos $f, above 10.9 (rustc clamps to 10.12 unless the link stamps 10.9)" ;; esac
  done
}

clock_gettime_defined() {
  nm -m "$RG" | grep -q '(__TEXT,__text) external _clock_gettime$' \
    || fail "clock_gettime_defined: rg does not define _clock_gettime, so the toolchain's legacy-support force-load did not reach the link"
}

gate_accepts_rg() {
  out="$(sh "$G" "$RG" 2>&1)" || fail "gate_accepts_rg: the gate refuses the built rg: $out"
}

command -v clang >/dev/null 2>&1 || fail "no clang: the gate's refusals cannot be proven without building fixtures, and the build needs a C linker anyway"
SDK="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"
SHIM_CLOCK='int clock_gettime(int c, void *t) { (void)c; (void)t; return 0; }'
SHIM_RANDOM='int CCRandomGenerateBytes(void *b, unsigned long n) { (void)b; (void)n; return 0; }'
fixture() {
  name="$1"; shift
  printf '%s\n' "$@" > "$t/$name.c"
  clang -arch x86_64 -isysroot "$SDK" -mmacosx-version-min=10.9 -Wl,-U,_os_unfair_lock_lock -o "$t/$name" "$t/$name.c" \
    || fail "could not build the $name fixture"
  printf '%s\n' "$t/$name"
}

shim_fixture_accepted() {
  f="$(fixture both "$SHIM_CLOCK" "$SHIM_RANDOM" 'int main(void) { return 0; }')"
  out="$(sh "$G" "$f" 2>&1)" || fail "shim_fixture_accepted: a 10.9-safe binary defining both shim symbols was refused, so the refusals below prove nothing: $out"
}

requires_shim_symbols() {
  for missing in _clock_gettime _CCRandomGenerateBytes; do
    case "$missing" in _clock_gettime) keep="$SHIM_RANDOM" ;; *) keep="$SHIM_CLOCK" ;; esac
    f="$(fixture "no$missing" "$keep" 'int main(void) { return 0; }')"
    if out="$(sh "$G" "$f" 2>&1)"; then
      fail "requires_shim_symbols: a binary not defining $missing passed; rg's std calls it and 10.9 lacks it, so the toolchain's shim must define it"
    fi
    case "$out" in *"$missing"*) : ;; *) fail "requires_shim_symbols: the refusal must name $missing: $out" ;; esac
  done
}

rejects_post_10_9_symbol() {
  f="$(fixture post 'void os_unfair_lock_lock(void *);' "$SHIM_CLOCK" "$SHIM_RANDOM" \
    'int main(void) { static int l; os_unfair_lock_lock(&l); return 0; }')"
  if out="$(sh "$G" "$f" 2>&1)"; then fail "rejects_post_10_9_symbol: the gate passed a binary importing _os_unfair_lock_lock"; fi
  case "$out" in *_os_unfair_lock_lock*) : ;; *) fail "rejects_post_10_9_symbol: the gate refused the fixture without naming _os_unfair_lock_lock: $out" ;; esac
}

build_runs_gate() {
  grep -q '^sh "\$REPO_ROOT/build/gate.sh" "\$OUT/bin/rg"$' "$ROOT/build/build.sh" \
    || fail "build_runs_gate: build/build.sh must gate the rg it builds before anything stages it"
}

floor_is_10_9; clock_gettime_defined; gate_accepts_rg; shim_fixture_accepted; requires_shim_symbols; rejects_post_10_9_symbol; build_runs_gate
echo "OK compat"
