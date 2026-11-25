# Build ingredients

Everything baked into the shipped `rg` `.pkg`, where it is pinned, and how a change reaches a
release. The *own upstream* is ripgrep; an ingredient is anything else the artifact is built with.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| ripgrep source (own upstream) | `UPSTREAM_VERSION` | ✅ `crate` datasource on `ripgrep` | cuts `<ver>-mavericks.1` |
| ripgrep's crate dependencies | upstream's `Cargo.lock`, inside the crate | ✅ move with the upstream pin | rebuilt with the new upstream |
| Rust toolchain (`rust` on 10.9, `rust-cross` on modern macOS) | `components/rust/version` | ✅ `github-releases` on `Mavergreen/rust`, `-mavericks.N` versioning | repackage → `-mavericks.(N+1)` |
| MacOSX10.9 SDK | shipyard `fetch_sdk.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |
| Sparkle (the updater) | shipyard `fetch_sparkle_framework.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |

Default ripgrep features only: the optional `pcre2` feature would add a C build and widen what must be
proven 10.9-safe, for no core-search benefit.

## Upstream source verification

The source is the `.crate` upstream publishes to crates.io, verified against the SHA-256 crates.io's
sparse index records for that exact version (`cksum`). A published version's index entry never
changes, so the checksum vouches for a version before anyone here has seen it, and a Renovate bump only
moves `UPSTREAM_VERSION`. Fail closed when the index has no entry for the version. ripgrep's GitHub
releases publish checksums for upstream's own binaries only, never for a source archive, so pinning
GitHub's tarball would need a hand-maintained hash that Renovate cannot move.

## Rust toolchain verification

Off Apple Silicon, shipyard's `cargo-env.sh` provides the pinned `Mavergreen/rust`: an installed
`/usr/local/mavergreen/rust` at the pin, else the release's Linux tarball (on Linux) or `.pkg` (on a
Mac), verified against that release's `SHA256SUMS` and unpacked, never installed. On Apple Silicon,
`build/fetch-rust.sh` does the same with the release's `rust-cross` `.pkg`. Either way the build needs
no root and uses exactly the pinned toolchain whatever else the host has installed.

## Running the shipped rg

CI builds on `ubuntu-latest` with the pinned rust's Linux toolchain, clang22 and the 10.9 SDK, all
through `cargo-env.sh`, so the x86_64 `rg` cannot run there: `tests/build-test.sh` checks it
statically, and a host `rg` built from the same source generates the man page and completions. The
`vm-test` job instead boots Mac OS X 10.9.5 with `Mavergreen/mavericks-vm`, installs the built `.pkg`,
and uses `rg` from a login shell (`build/check-release-on-10.9.sh`, the same check a maintainer runs on
real hardware after a release). Publishing waits for it.

## Declared state

- upstream: UPSTREAM_VERSION
- rust: components/rust/version
