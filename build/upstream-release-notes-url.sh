#!/bin/sh
# platform: host-agnostic
#   usage: upstream-release-notes-url.sh <upstream-version>     prints ripgrep's notes URL for it
set -eu
printf 'https://github.com/BurntSushi/ripgrep/releases/tag/%s\n' "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
