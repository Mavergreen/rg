# platform: host-agnostic
#   usage: . build/versions.sh     the product's identity, pins and build locations
: "${REPO_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
export REPO_ROOT
MAVERICKS_ROOT="$REPO_ROOT"; export MAVERICKS_ROOT
. "$REPO_ROOT/build/lib.sh"

MAVERICKS_UPSTREAM_FILE="$REPO_ROOT/UPSTREAM_VERSION"; export MAVERICKS_UPSTREAM_FILE
[ -f "$MAVERICKS_UPSTREAM_FILE" ] || { echo "versions.sh: no UPSTREAM_VERSION at repo root" >&2; exit 1; }
RG_VERSION="$(upstream_version)"; export RG_VERSION
[ -n "$RG_VERSION" ] || { echo "versions.sh: empty UPSTREAM_VERSION" >&2; exit 1; }

RUST_PIN_FILE="$REPO_ROOT/components/rust/version"; export RUST_PIN_FILE
RUST_VERSION="$(tr -d ' \t\n' < "$RUST_PIN_FILE")"; export RUST_VERSION
[ -n "$RUST_VERSION" ] || { echo "versions.sh: empty $RUST_PIN_FILE" >&2; exit 1; }

export SHORT="rg"
export IDENTIFIER="dev.mavergreen.rg"
export PREFIX="/usr/local/mavergreen/$SHORT"
export TARGET_TRIPLE="x86_64-apple-darwin"
export MACOS_MIN="10.9"

# spec: SKILL.md "Build OUT of the source tree" -- keyed by the checkout's directory name, so two
#       checkouts never share a build tree
WORK="${MAVERICKS_BUILD_ROOT:-${TMPDIR:-/tmp}/mm-build}/$(basename "$REPO_ROOT")"; export WORK
