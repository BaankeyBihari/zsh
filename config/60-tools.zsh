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

# fzf keybindings — rebinds Ctrl-R (fuzzy history), Ctrl-T (fuzzy file insert),
# Alt-C (fuzzy cd). Sourced from the brew-shipped file instead of `eval "$(fzf --zsh)"`:
# no subprocess at startup, and completion.zsh (** fuzzy tab-completion) is deliberately
# NOT wired. HOMEBREW_PREFIX comes from brew shellenv in ~/.zshenv.
[[ -r "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]] && \
  source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
