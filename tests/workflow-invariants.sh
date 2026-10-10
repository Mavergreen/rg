#!/bin/sh
# platform: host-agnostic
#   usage: tests/workflow-invariants.sh     the release workflow gates, notes, signs and publishes in
#          the family's order, with the least privilege each job needs
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/.github/workflows/release.yml"
fail() { echo "FAIL workflow-invariants: $1"; exit 1; }
[ -f "$W" ] || fail "no .github/workflows/release.yml"
code() { grep -v '^[[:space:]]*#' "$1"; }
line_of() { code "$W" | grep -n -- "$1" | sed -n '1s/:.*//p'; }
before() {
  a="$(line_of "$1")"; b="$(line_of "$2")"
  [ -n "$a" ] || fail "release.yml never runs $1"
  [ -n "$b" ] || fail "release.yml never runs $2"
  [ "$a" -lt "$b" ] || fail "$3"
}

code "$W" | awk '/^on:/{o=1; next} o && /^[^ ]/{o=0} o' | grep -A1 '^  pull_request:' | grep -q 'branches: \[main\]' \
  || fail "no pull_request trigger on main: Renovate's automerge waits on this build, and would stall forever"
if code "$W" | grep -q 'pull_request_target'; then fail "pull_request_target would hand a fork PR this repo's secrets"; fi
code "$W" | awk '/^permissions:/{p=1; next} p && /^[^ ]/{p=0} p' | grep -qx '  contents: read' \
  || fail "top-level permissions must be contents: read; only publish writes"
code "$W" | awk '/^  publish:/{p=1; next} p && /^  [a-z]/{p=0} p' | grep -q 'contents: write' || fail "publish must declare its own contents: write"
nco="$(code "$W" | grep -c 'uses: actions/checkout@')"
npc="$(code "$W" | grep -c 'persist-credentials: false')"
[ "$nco" = "$npc" ] || fail "every checkout needs persist-credentials: false ($nco checkouts, $npc without persisted credentials)"

before 'sh build/build.sh' 'sh build/package.sh' "the build (which gates rg as 10.9-safe) must run before packaging"
before 'sh build/package.sh' 'run-repo-tests.sh' "the tests read the built pkg, so packaging must come first"
before 'release-notes.sh' 'release-state-record.sh' "the declared state is recorded into the generated notes"
before 'release-state-record.sh' 'sign_and_appcast.sh' "the notes, state marker included, must be final before the appcast embeds them"
before 'sign_and_appcast.sh' 'check-artifact-conformance.sh' "conformance checks the feed against the pkg, so the feed must exist"
code "$W" | grep -q -- '--product rg --feed-dir dist' || fail "sign_and_appcast.sh must write dist/rg.xml (--product rg --feed-dir dist)"
code "$W" | grep -q -- '--min-os 10.9.5' || fail "the feed and the notes must declare the 10.9.5 floor"
code "$W" | grep -q 'stand-in-feeds.sh' || fail "an unsigned build needs stand-in feeds, or conformance cannot check the updater's feed"
code "$W" | grep -q 'uses: Mavergreen/shipyard/.github/workflows/scan-for-key.yml@v1' || fail "a signing run must prove its logs do not carry the key"
code "$W" | awk '/^  publish:/{p=1; next} p && /^  [a-z]/{p=0} p' | grep 'needs:' | grep -q 'scan' || fail "publish must wait for the key scan"
code "$W" | grep -q 'check-ingredient-pins.sh' || fail "the ingredient pin declaration is never checked"

if code "$W" | grep -q -i rosetta; then fail "release.yml must not use Rosetta: the shipped x86_64 rg runs on Mac OS X 10.9, in the vm-test job"; fi
if grep -q "^- rosetta:" "$ROOT/INGREDIENTS.md"; then fail "INGREDIENTS.md declares a Rosetta use, but nothing here runs translated any more"; fi
vm="$(code "$W" | awk "/^  vm-test:/{f=1;print;next} /^  [a-z][a-z-]*:\$/{f=0} f")"
[ -n "$vm" ] || fail "no vm-test job: nothing runs the shipped x86_64 rg on Mac OS X 10.9 before it ships"
printf "%s\n" "$vm" | grep -q "uses: Mavergreen/mavericks-vm@v1" || fail "vm-test must boot Mac OS X 10.9 with Mavergreen/mavericks-vm"
printf "%s\n" "$vm" | grep -q "needs: \[build\]" || fail "vm-test must test the pkg the build job made"
printf "%s\n" "$vm" | grep -q "name: mavergreen-rg, path: dist" || fail "vm-test must install the pkg the build job uploaded"
printf "%s\n" "$vm" | grep -q "build/check-release-on-10.9.sh" || fail "vm-test must install and use the pkg on 10.9 with build/check-release-on-10.9.sh"
printf "%s\n" "$vm" | grep -q "packages: write" || fail "vm-test needs packages: write for mavericks-vm's shared guest cache"
printf "%s\n" "$vm" | grep -q "image-key: \${{ secrets.MAVERICKS_VM_KEY }}" || fail "vm-test must hand mavericks-vm the org's image key"
code "$W" | awk "/^  publish:/{f=1;next} /^  [a-z][a-z-]*:\$/{f=0} f&&/needs:/" | grep -q "vm-test" \
  || fail "publish must wait for vm-test: an rg that did not run on 10.9 must not ship"

R="$ROOT/.github/workflows/repackage-on-ingredient-bump.yml"
[ -f "$R" ] || fail "no repackage-on-ingredient-bump.yml: a new Mavergreen/rust would never reach a release"
code "$R" | grep -q 'components/\*\*' || fail "the repackage caller must watch components/**"
code "$R" | grep -q 'own-upstream-paths: UPSTREAM_VERSION' || fail "a new upstream is not a repackage"
C="$ROOT/.github/workflows/reconcile.yml"
[ -f "$C" ] || fail "no reconcile.yml: nothing would notice a declared state that never released"
code "$C" | grep -q 'actions: write' || fail "reconcile must be granted actions: write to dispatch release.yml"
echo "OK workflow-invariants"
