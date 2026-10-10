#!/bin/sh
# platform: macOS-only -- pkgutil expands the pkg
#   usage: tests/package-test.sh     the pkg installs rg, its man page and completions, and its updater,
#          in place, behind the 10.9.5 floor
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$ROOT"; export REPO_ROOT
fail() { echo "FAIL package: $1"; exit 1; }
[ -f "$ROOT/build/package.sh" ] || fail "no build/package.sh"
. "$ROOT/build/versions.sh"
set -- "$ROOT"/dist/rg-*.pkg
[ -f "$1" ] || { echo "SKIP package: not packaged -- run build/build.sh, then build/package.sh"; exit 77; }
[ "$#" -eq 1 ] || fail "dist/ holds $# rg pkgs; one build makes one"
PKG="$1"
t="$(mktemp -d "${TMPDIR:-/tmp}/rg-package-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT
pkgutil --expand "$PKG" "$t/x"
comp="$t/x/rg-component.pkg"
[ -f "$comp/Payload" ] || fail "$PKG has no rg-component.pkg"
mkdir "$t/root"
tar -xf "$comp/Payload" -C "$t/root"
P="$t/root$PREFIX"

ships_generated_man_and_completions() {
  for f in bin/rg share/man/man1/rg.1 share/bash-completion/completions/rg share/zsh/site-functions/_rg \
           share/fish/vendor_completions.d/rg.fish mavergreen.plist; do
    [ -s "$P/$f" ] || fail "ships_generated_man_and_completions: the pkg does not install $PREFIX/$f"
  done
  cmp -s "$P/bin/rg" "$WORK/out/bin/rg" || fail "ships_generated_man_and_completions: the pkg's rg is not the one build.sh gated"
  for f in share/man/man1/rg.1 share/bash-completion/completions/rg share/zsh/site-functions/_rg share/fish/vendor_completions.d/rg.fish; do
    cmp -s "$P/$f" "$WORK/out/$f" || fail "ships_generated_man_and_completions: the pkg's $f is not the one build.sh generated"
  done
}

ships_its_updater() {
  app="$t/root/Library/Application Support/Mavergreen/rg-updater.app"
  [ -d "$app" ] || fail "ships_its_updater: no rg-updater.app"
  [ -f "$t/root/Library/LaunchAgents/dev.mavergreen.rg-updatecheck.plist" ] || fail "ships_its_updater: no update-check LaunchAgent"
  feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")"
  [ "$feed" = "https://github.com/Mavergreen/rg/releases/latest/download/rg.xml" ] || fail "ships_its_updater: SUFeedURL is $feed"
  if otool -L "$app/Contents/MacOS/"* | grep -q "$PREFIX"; then fail "ships_its_updater: the updater links the product it updates"; fi
  sh "$SHIPYARD_SCRIPTS/assert_sparkle_pristine.sh" "$app/Contents/Frameworks/Sparkle.framework" "$(sh "$SHIPYARD_SCRIPTS/fetch_sparkle_framework.sh")" \
    || fail "ships_its_updater: the embedded Sparkle.framework is not the pinned one"
}

installs_in_place() {
  sh "$SHIPYARD_SCRIPTS/assert_pkg_installs_in_place.sh" "$PKG" || fail "installs_in_place: the pkg would relocate or version-skip a bundle"
}

upgrade_clears_prefix() {
  pre="$comp/Scripts/preinstall"
  [ -f "$pre" ] || fail "upgrade_clears_prefix: no preinstall, so files a newer version drops would linger in $PREFIX"
  grep -q "^rm -rf \"\$ROOT$PREFIX\" " "$pre" \
    || fail "upgrade_clears_prefix: the preinstall does not remove $PREFIX before the new payload lands"
  sh -n "$pre" || fail "upgrade_clears_prefix: the preinstall does not parse"
}

floor_and_base() {
  d="$t/x/Distribution"
  grep -q '<os-version min="10.9.5"' "$d" || fail "floor_and_base: the Distribution does not declare the 10.9.5 floor"
  first="$(awk '/<choices-outline>/{o=1} o && /<line choice="/ && !/choice="default"/ { sub(/.*<line choice="/, ""); sub(/".*/, ""); print; exit }' "$d")"
  [ "$first" = dev.mavergreen.base ] || fail "floor_and_base: dev.mavergreen.base must be the first component, not $first"
  grep -q "id=\"$IDENTIFIER\"" "$d" || fail "floor_and_base: no $IDENTIFIER component"
}

ships_generated_man_and_completions; ships_its_updater; installs_in_place; upgrade_clears_prefix; floor_and_base
echo "OK package"
