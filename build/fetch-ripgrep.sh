#!/bin/sh
# platform: host-agnostic
#   usage: fetch-ripgrep.sh     prints the path of a fresh, verified ripgrep source tree under $WORK
#          The source is the .crate upstream published to crates.io, accepted only when its SHA-256
#          is the one crates.io's sparse index records for UPSTREAM_VERSION. RG_INDEX_URL and
#          RG_CRATE_URL override where the index entry and the crate come from (the tests use them).
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"
. "$SHIPYARD_SCRIPTS/mavericks_fetch.sh"
INDEX_URL="${RG_INDEX_URL:-https://index.crates.io/ri/pg/ripgrep}"
CRATE_URL="${RG_CRATE_URL:-https://static.crates.io/crates/ripgrep/ripgrep-$RG_VERSION.crate}"

entries="$(shipyard_curl "$INDEX_URL" -)" || { echo "fetch-ripgrep: cannot read the crates.io index at $INDEX_URL" >&2; exit 1; }
[ -n "$entries" ] || { echo "fetch-ripgrep: the crates.io index at $INDEX_URL is empty" >&2; exit 1; }
vre="$(printf '%s' "$RG_VERSION" | sed 's/[.]/[.]/g')"
sha="$(printf '%s\n' "$entries" | sed -n "/\"name\":\"ripgrep\",\"vers\":\"$vre\"/s/.*\"cksum\":\"\([0-9a-f]\{64\}\)\".*/\1/p")"
case "$sha" in
  "") echo "fetch-ripgrep: crates.io lists no ripgrep $RG_VERSION with a checksum -- refusing an unverified source" >&2; exit 1 ;;
  *[!0-9a-f]*) echo "fetch-ripgrep: crates.io lists ripgrep $RG_VERSION more than once -- refusing to guess which checksum holds" >&2; exit 1 ;;
esac

CACHE="$WORK/src"
# spec: shipyard scripts/mavericks_fetch.sh usage -- shipyard_fetch_pinned keeps an existing entry, so the
#       caller removes the old tree to extract afresh
rm -rf "$CACHE/ripgrep-$RG_VERSION"
shipyard_fetch_pinned "$CRATE_URL" "$sha" "$CACHE" "ripgrep-$RG_VERSION.crate" \
  || { echo "fetch-ripgrep: ripgrep $RG_VERSION failed verification against crates.io's checksum" >&2; exit 1; }
SRC="$CACHE/ripgrep-$RG_VERSION"
grep -q "^version = \"$vre\"\$" "$SRC/Cargo.toml" 2>/dev/null \
  || { echo "fetch-ripgrep: $SRC/Cargo.toml is not version $RG_VERSION" >&2; exit 1; }
printf '%s\n' "$SRC"
