# Version managers and other tool initialisations that emit shell hooks.

# fnm — fast Node version manager. --use-on-cd swaps Node when .nvmrc changes.
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# pyenv shims + completions.
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# zoxide — smarter cd. Provides `z <dir>` (jump) and `zi` (interactive fzf pick).
# `j` is aliased to `z` in config/70-aliases.zsh so both keystrokes share one database.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
