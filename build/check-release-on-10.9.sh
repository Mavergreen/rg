#!/bin/sh
# platform: macOS-only -- installer, pkgutil and sw_vers; meant for real 10.9
#   usage: check-release-on-10.9.sh <version>
#          Run ON Mac OS X 10.9: in CI by release.yml's vm-test job, and on real hardware after a
#          release, before trusting it. Downloads and verifies rg-<version>.pkg, installs it, uses
#          rg the way a user would, uninstalls it. One PASS/FAIL line per step;
#          exit 1 if any step failed. MAVERICKS_RELEASE_BASE overrides where the pkg and SHA256SUMS
#          come from (default: the version's GitHub release), e.g. file:///path for a local dist/.
set -u
V="${1:-}"
[ -n "$V" ] || { echo "usage: check-release-on-10.9.sh <version>   (e.g. 15.2.0-mavericks.1)" >&2; exit 2; }
os="${MAVERICKS_CHECK_OS:-$(sw_vers -productVersion 2>/dev/null)}"
case "$os" in 10.9|10.9.*) : ;; *) echo "check-release-on-10.9.sh: run this on Mac OS X 10.9 (this is $os)" >&2; exit 2 ;; esac
base="${MAVERICKS_RELEASE_BASE:-https://github.com/Mavergreen/rg/releases/download/$V}"
pkg="rg-$V.pkg"
w="$(mktemp -d "${TMPDIR:-/tmp}/rg-release-check.XXXXXX")"
bad=0
step() {
  name="$1"; shift
  if ( "$@" ) > "$w/$name.log" 2>&1; then echo "PASS $name"; else echo "FAIL $name (log: $w/$name.log)"; bad=1; fi
}
fetch() {
  curl -fsSL -o "$w/$pkg" "$base/$pkg" || return 1
  curl -fsSL -o "$w/SHA256SUMS" "$base/SHA256SUMS" || return 1
  n="$(grep -c " $pkg\$" "$w/SHA256SUMS")"
  [ "$n" = 1 ] || { echo "$pkg is listed $n times in SHA256SUMS"; return 1; }
  ( cd "$w" && grep " $pkg\$" SHA256SUMS | shasum -a 256 -c - )
}
install_pkg() { sudo installer -pkg "$w/$pkg" -target / && /usr/local/bin/mavergreen check; }
# platform: /usr/local/mavergreen/bin reaches PATH and MANPATH only through a login shell's paths.d
L() { /bin/zsh -lc "$1"; }
version() {
  out="$(L 'rg --version' 2>&1)" || { printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out"
  case "$out" in *dyld*) return 1 ;; "ripgrep ${V%-mavericks.*}"*) return 0 ;; *) return 1 ;; esac
}
search() {
  mkdir -p "$w/tree/sub" && printf 'needle\n' > "$w/tree/sub/a.txt" && printf 'hay\n' > "$w/tree/b.txt"
  [ "$(L "cd '$w/tree' && rg --no-config -l needle")" = sub/a.txt ]
}
manpage() { L 'man -w rg' | grep -q '/usr/local/mavergreen/share/man/man1/rg.1'; }
uninstall() {
  sudo /usr/local/bin/mavergreen uninstall rg || return 1
  [ ! -e /usr/local/mavergreen/rg ] || return 1
  if pkgutil --pkgs | grep -qx dev.mavergreen.rg; then return 1; fi
}
step fetch-and-verify fetch
[ "$bad" = 0 ] || { echo "SOME FAILED $V -- not installing a pkg that did not verify"; exit 1; }
step install install_pkg
step version version
step search search
step manpage manpage
step uninstall uninstall
if [ "$bad" = 0 ]; then echo "ALL PASS $V"; else echo "SOME FAILED $V -- fix forward in the next -mavericks.N"; exit 1; fi
