# $ZDOTDIR/.zshrc — interactive shell entry point.
#
# This file is intentionally a tiny driver. All real configuration lives in numbered
# NN-*.zsh fragments alongside it. To add behaviour, drop a new fragment in this
# directory; do not extend this file.
#
# Load order is lexical by filename. 99-local.zsh (gitignored, optional) is naturally
# last, which makes it the machine-specific override layer.

for _zsh_fragment in "${ZDOTDIR:-$HOME/.config/zsh}"/[0-9][0-9]-*.zsh(N); do
  source "$_zsh_fragment"
done
unset _zsh_fragment
