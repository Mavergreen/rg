#!/bin/sh
# platform: host-agnostic -- shipyard's stage_product.sh, build_component_pkg.sh and set_install_floor.sh make the pkg
#   usage: package.sh     wraps the gated rg, its man page, completions and updater into
#          dist/rg-<version>.pkg
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
# platform: without it, a Mac's cp carries AppleDouble ._ files into the payload
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
OUT="$WORK/out"
[ -x "$OUT/bin/rg" ] || { echo "package: no $OUT/bin/rg -- run build/build.sh first" >&2; exit 1; }
sh "$REPO_ROOT/build/gate.sh" "$OUT/bin/rg"
VER="$(sh "$SHIPYARD_SCRIPTS/resolve-version.sh" "$(sh "$SHIPYARD_SCRIPTS/release-mode.sh")")"

pr="$WORK/pkgroot"; scr="$WORK/pkg-scripts"; comp="$WORK/$SHORT-component.pkg"
rm -rf "$pr" "$scr" "$comp"
mkdir -p "$pr$(dirname "$PREFIX")" "$REPO_ROOT/dist"
rm -f "$REPO_ROOT"/dist/"$SHORT"-*.pkg
mkdir -p "$pr$PREFIX"
cp -R "$OUT/." "$pr$PREFIX"
app="$(sh "$REPO_ROOT/build/build-updater.sh" "$VER" "$WORK/updater")"
find "$pr" -name '._*' -delete
sh "$SHIPYARD_SCRIPTS/stage_product.sh" --stage "$pr" --product "$SHORT" --name "ripgrep for Mavericks" \
  --version "$VER" --scripts-out "$scr" --updater-app "$app"
sh "$SHIPYARD_SCRIPTS/build_component_pkg.sh" --root "$pr" --identifier "$IDENTIFIER" --version "$VER" \
  --install-location / --scripts "$scr" --out "$comp" >/dev/null
pkg="$REPO_ROOT/dist/$SHORT-$VER.pkg"
sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" --identifier "$IDENTIFIER" --title "ripgrep for Mavericks $VER" \
  --component "$comp" --out "$pkg" --min-os 10.9.5 --host-arch x86_64 --require-scripts >/dev/null
rm -f "$comp"
sh "$SHIPYARD_SCRIPTS/assert_pkg_installs_in_place.sh" "$pkg"
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$REPO_ROOT/dist/build-info-native.txt" \
  variant=native arch=x86_64 prefix="$PREFIX" pkg="$(basename "$pkg")" identifier="$IDENTIFIER" \
  ripgrep="$RG_VERSION" rust="$RUST_VERSION" target="$TARGET_TRIPLE"
echo ">> packaged $pkg"
