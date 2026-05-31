# Completion paths + compinit. Runs after plugins so any plugin-provided fpath entries
# are in place.

fpath=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"(N)
  /opt/homebrew/share/zsh/site-functions(N)
  /opt/homebrew/share/zsh-completions(N)
  $fpath
)

autoload -Uz compinit
# -C: skip the daily security check; regen the dump only when stale. Keeps startup fast.
compinit -C
