#!/bin/sh
# platform: host-agnostic -- shipyard's cargo-env.sh on an x86_64 host, the pinned rust-cross on Apple Silicon
#   usage: build.sh     builds rg for x86_64 10.9 into $WORK/out/bin, its man page and completions
#          into $WORK/out/share
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
TC="$(sh "$REPO_ROOT/build/rust-toolchain.sh" "$(uname -s)" "$(uname -m)")"
SRC="$(sh "$REPO_ROOT/build/fetch-ripgrep.sh")"
OUT="$WORK/out"
case "$TC" in
  cargo-env)
    if [ -z "${CARGO:-}" ] || [ "${CARGO_BUILD_TARGET:-}" != "$TARGET_TRIPLE" ]; then
      env="$(sh "$SHIPYARD_SCRIPTS/cargo-env.sh" --sh "$REPO_ROOT/components/rust")" || exit 1
      eval "$env"
    fi ;;
  rust-cross)
    RUST="$(sh "$REPO_ROOT/build/fetch-rust.sh")"
    SDK="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"
    case "$SDK" in *[[:space:]]*) echo "build: the SDK path $SDK contains whitespace, which cargo would split inside its rustflags -- set MAVERICKS_SDK_CACHE to a path without any" >&2; exit 1 ;; esac
    CARGO="$RUST/bin/cargo" RUSTC="$RUST/bin/rustc" RUSTDOC="$RUST/bin/rustdoc"
    export CARGO RUSTC RUSTDOC
    # platform: with --target, cargo applies target.<triple>.rustflags to rg alone, never to build
    #           scripts; SDKROOT would also reach the build scripts, which on Apple Silicon are arm64
    #           and cannot link against the 10.9 SDK
    unset SDKROOT
    CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$SDK"
    export CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS ;;
esac
CARGO_HOME="$WORK/cargo-home"; export CARGO_HOME
CARGO_TARGET_DIR="$WORK/target"; export CARGO_TARGET_DIR
# platform: ripgrep's build.rs embeds `git rev-parse HEAD` from whatever checkout encloses the source
GIT_CEILING_DIRECTORIES="$(dirname "$SRC")"; export GIT_CEILING_DIRECTORIES
# platform: cargo prefers either over the per-target flags, and a developer's would reach the 10.9 link
unset RUSTFLAGS CARGO_ENCODED_RUSTFLAGS

# platform: 10.9 and modern macOS run /bin/sh as bash 3.2, whose set -e ignores a failing ( ) subshell
( cd "$SRC" && "$CARGO" build --release --locked --target "$TARGET_TRIPLE" ) || exit 1
built="$CARGO_TARGET_DIR/$TARGET_TRIPLE/release/rg"
[ -x "$built" ] || { echo "build: cargo produced no $built" >&2; exit 1; }

# spec: shipyard SKILL.md "Rosetta" -- no build step runs translated or off macOS, so anywhere but an
#       x86_64 Mac a host rg built from the same source generates the man page and completions
case "$(uname -s):$(uname -m)" in
  Darwin:x86_64) gen="$built" ;;
  *)
    host="$("$RUSTC" -vV | sed -n 's/^host: //p')"
    ( cd "$SRC" && "$CARGO" build --release --locked --target "$host" ) || exit 1
    gen="$CARGO_TARGET_DIR/$host/release/rg" ;;
esac

rm -rf "$OUT"
mkdir -p "$OUT/bin" "$OUT/share/man/man1" "$OUT/share/bash-completion/completions" \
  "$OUT/share/zsh/site-functions" "$OUT/share/fish/vendor_completions.d"
cp "$built" "$OUT/bin/rg"
sh "$REPO_ROOT/build/gate.sh" "$OUT/bin/rg"
generate() {
  "$gen" --generate "$1" > "$OUT/$2" || { echo "build: rg --generate $1 failed" >&2; exit 1; }
  [ -s "$OUT/$2" ] || { echo "build: rg --generate $1 wrote nothing" >&2; exit 1; }
}
generate man share/man/man1/rg.1
generate complete-bash share/bash-completion/completions/rg
generate complete-zsh share/zsh/site-functions/_rg
generate complete-fish share/fish/vendor_completions.d/rg.fish
echo ">> built $OUT/bin/rg ($TC)"
