# Completion fpath only. znap (config/30-znap.zsh, loaded earlier) OWNS compinit: it
# stubs `compinit` and runs the real one from a precmd hook on the first prompt, dumping
# to $XDG_CACHE_HOME/zsh/compdump. We just make sure extra completion dirs are on fpath
# before that hook fires — which they are, since this fragment loads well before the
# first prompt.
#
# Do NOT call compinit here. znap's stub makes a plain `compinit` a no-op (and
# `autoload -Uz compinit` does NOT un-stub an already-defined function), so any call here
# is either dead code or — if it did run the real compinit — a second redundant pass that
# fights znap over the dumpfile location and leaves a stray ~/.config/zsh/.zcompdump-*.

fpath=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"(N)
  /opt/homebrew/share/zsh/site-functions(N)
  /opt/homebrew/share/zsh-completions(N)
  $fpath
)
