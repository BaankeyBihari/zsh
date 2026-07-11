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

# fzf look & feel + listers. rg respects .gitignore, so Ctrl-T doesn't drown in
# node_modules; falls back to fzf's built-in walker when rg is absent (guard below).
# Previews: bat for files (Ctrl-T), eza tree for directories (Alt-C) — both degrade
# to no preview if the tool is missing, since fzf just shows the failed command.
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
if command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
command -v bat >/dev/null 2>&1 && \
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
command -v eza >/dev/null 2>&1 && \
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
