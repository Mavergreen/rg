# `rg` for Mavericks

[ripgrep](https://github.com/BurntSushi/ripgrep) for Mac OS X 10.9 Mavericks. An unofficial
community build, not affiliated with ripgrep or its author.

## Shell completions

Add to your shell startup file:

- `~/.bash_profile`: `. /usr/local/mavergreen/rg/share/bash-completion/completions/rg`
- `~/.zshrc`: `fpath=(/usr/local/mavergreen/rg/share/zsh/site-functions $fpath)`, then, unless your
  `~/.zshrc` already runs it, `autoload -U compinit && compinit`
- `~/.config/fish/config.fish`: `set -p fish_complete_path /usr/local/mavergreen/rg/share/fish/vendor_completions.d`
