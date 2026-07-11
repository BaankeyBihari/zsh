# Plugin manifest. Adding / removing a plugin = editing this file + re-running install.sh
# (or `zsh -i -c 'znap pull'` to update existing clones).
#
# Order matters: zsh-syntax-highlighting must be sourced last to wrap other widgets.

# Skip cleanly if znap failed to load (e.g. offline first run) — see 30-znap.zsh.
(( $+functions[znap] )) || return 0

# Suggest from history first, then fall back to the completion engine when history
# has no match. Must be set before the plugin loads.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
znap source zsh-users/zsh-autosuggestions
znap source zsh-users/zsh-syntax-highlighting
