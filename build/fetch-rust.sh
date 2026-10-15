#!/bin/sh
# platform: macOS-only -- pkgutil expands the toolchain pkg
#   usage: fetch-rust.sh     prints the prefix of the pinned Mavergreen/rust toolchain for this host
#          On an x86_64 Mac (10.9 or modern) that is rust; on Apple Silicon, rust-cross, which runs
#          there and targets 10.9 (build/rust-toolchain.sh decides). The pkg is verified against its release's
#          SHA256SUMS, then extracted under $WORK -- never installed, so no root is needed and the
#          build uses exactly the pinned toolchain.
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
. "$SHIPYARD_SCRIPTS/mavericks_fetch.sh"
short="$(sh "$REPO_ROOT/build/rust-toolchain.sh" "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" "$(uname -m)")"
base="https://github.com/Mavergreen/rust/releases/download/$RUST_VERSION"
pkg="$short-$RUST_VERSION.pkg"
dir="$WORK/toolchain/$short-$RUST_VERSION"
tc="$dir/root/usr/local/mavergreen/$short"
if [ -f "$dir/extracted" ] && [ -x "$tc/bin/cargo" ]; then printf '%s\n' "$tc"; exit 0; fi

mkdir -p "$dir"
sums="$(shipyard_curl "$base/SHA256SUMS" -)" || { echo "fetch-rust: cannot read $base/SHA256SUMS" >&2; exit 1; }
sha="$(printf '%s\n' "$sums" | awk -v f="$pkg" '$2 == f || $2 == "*" f { print $1 }')"
case "$sha" in
  "") echo "fetch-rust: $pkg is not listed in $base/SHA256SUMS -- refusing an unverified toolchain" >&2; exit 1 ;;
  *[!0-9a-f]*) echo "fetch-rust: $pkg is listed more than once in $base/SHA256SUMS" >&2; exit 1 ;;
esac
shipyard_fetch_verified "$base/$pkg" "$sha" "$dir" "$pkg" || { echo "fetch-rust: $pkg failed verification" >&2; exit 1; }

rm -rf "$dir/expanded" "$dir/root" "$dir/extracted"
pkgutil --expand "$dir/$pkg" "$dir/expanded"
payload="$dir/expanded/$short-component.pkg/Payload"
[ -f "$payload" ] || { echo "fetch-rust: $pkg has no $short-component.pkg payload" >&2; exit 1; }
mkdir -p "$dir/root"
# platform: bsdtar reads a pkg Payload (gzip-compressed cpio) directly, so no pipe can hide a
#           truncated extraction
tar -xf "$payload" -C "$dir/root"
rm -rf "$dir/expanded"
[ -x "$tc/bin/cargo" ] && [ -x "$tc/bin/rustc" ] || { echo "fetch-rust: $pkg holds no cargo and rustc under usr/local/mavergreen/$short" >&2; exit 1; }
: > "$dir/extracted"
printf '%s\n' "$tc"
