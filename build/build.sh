#!/bin/sh
# platform: macOS-only -- the Rust toolchain and the 10.9 SDK it links against are macOS's
#   usage: build.sh     builds rg for x86_64 10.9 into $WORK/out/bin, its man page and completions
#          into $WORK/out/share
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
MODE="$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")"
RUST="$(sh "$REPO_ROOT/build/fetch-rust.sh")"
SRC="$(sh "$REPO_ROOT/build/fetch-ripgrep.sh")"
SDK="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"
case "$SDK" in *[[:space:]]*) echo "build: the SDK path $SDK contains whitespace, which cargo would split inside its rustflags -- set MAVERICKS_SDK_CACHE to a path without any" >&2; exit 1 ;; esac
OUT="$WORK/out"

CARGO_HOME="$WORK/cargo-home"; export CARGO_HOME
CARGO_TARGET_DIR="$WORK/target"; export CARGO_TARGET_DIR
RUSTC="$RUST/bin/rustc"; export RUSTC
RUSTDOC="$RUST/bin/rustdoc"; export RUSTDOC
# platform: ripgrep's build.rs embeds `git rev-parse HEAD` from whatever checkout encloses the source
GIT_CEILING_DIRECTORIES="$(dirname "$SRC")"; export GIT_CEILING_DIRECTORIES
# platform: with --target, cargo applies target.<triple>.rustflags to rg alone, never to build
#           scripts; SDKROOT would also reach the build scripts, which on Apple Silicon are arm64
#           and cannot link against the 10.9 SDK
unset SDKROOT RUSTFLAGS CARGO_ENCODED_RUSTFLAGS
CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$SDK"
export CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS

# platform: 10.9 and modern macOS run /bin/sh as bash 3.2, whose set -e ignores a failing ( ) subshell
( cd "$SRC" && "$RUST/bin/cargo" build --release --locked --target "$TARGET_TRIPLE" ) || exit 1
built="$CARGO_TARGET_DIR/$TARGET_TRIPLE/release/rg"
[ -x "$built" ] || { echo "build: cargo produced no $built" >&2; exit 1; }

# spec: shipyard SKILL.md "Rosetta" -- no build step runs translated, so off x86_64 a
#       host-arch rg built from the same source generates the man page and completions
case "$(uname -m)" in
  x86_64) gen="$built" ;;
  *)
    ( cd "$SRC" && "$RUST/bin/cargo" build --release --locked ) || exit 1
    gen="$CARGO_TARGET_DIR/release/rg" ;;
esac

rm -rf "$OUT"
mkdir -p "$OUT/bin" "$OUT/share/man/man1" "$OUT/share/bash-completion/completions" \
  "$OUT/share/zsh/site-functions" "$OUT/share/fish/vendor_completions.d"
cp "$built" "$OUT/bin/rg"
generate() {
  "$gen" --generate "$1" > "$OUT/$2" || { echo "build: rg --generate $1 failed" >&2; exit 1; }
  [ -s "$OUT/$2" ] || { echo "build: rg --generate $1 wrote nothing" >&2; exit 1; }
}
generate man share/man/man1/rg.1
generate complete-bash share/bash-completion/completions/rg
generate complete-zsh share/zsh/site-functions/_rg
generate complete-fish share/fish/vendor_completions.d/rg.fish
echo ">> built $OUT/bin/rg ($MODE)"
