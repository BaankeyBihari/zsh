# eza — modern ls (icons need the Nerd Font from the Brewfile). Guarded: on a machine
# without eza the plain-ls fallbacks below stay in effect. No --color=always anywhere:
# eza's auto-detection keeps pipes clean. Real tree stays reachable as `command tree`.
if command -v eza >/dev/null 2>&1; then
  # --icons=auto / --classify=auto (with the =): both flags take an OPTIONAL value,
  # so the bare form followed by a path swallows the path as its value
  # (`tree bin/` → "invalid value 'bin/' for '--icons'").
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lh --icons=auto --git --group-directories-first'
  alias la='eza -lah --icons=auto --group-directories-first'
  alias tree='eza --tree --icons=auto'
  alias l='eza --icons=auto --classify=auto'   # ≈ ls -CF (grid + type suffixes)
else
  alias ll='ls -la'
  alias la='ls -A'
  alias l='ls -CF'
fi

# bat — cat with syntax highlighting in a tty; degrades to plain output in pipes and
# scripts, so the shadow is safe. --style=auto keeps `cat file` free of gutter noise.
command -v bat >/dev/null 2>&1 && alias cat='bat --style=auto'

alias c='clear'
alias j='z'   # muscle-memory: `j` jumps via zoxide (see config/60-tools.zsh)
# `cdir` (-> ~/.gemini/antigravity/scratch) removed pending a proper Antigravity/Gemini
# install. Re-add once the scratch/workspace location is settled.
