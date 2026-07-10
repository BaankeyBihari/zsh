# $ZDOTDIR/.zshrc — interactive shell entry point.
#
# This file is intentionally a tiny driver. All real configuration lives in numbered
# NN-*.zsh fragments, which bin/install.sh copies into $ZDOTDIR/zsh.d/. To add behaviour,
# drop a new fragment in the repo's config/ and re-run install.sh; do not extend this file.
#
# Load order is lexical by filename. 99-local.zsh (gitignored, optional) lives at the
# $ZDOTDIR root — outside zsh.d/ so an install never purges it — and is sourced last,
# which makes it the machine-specific override layer.

for _zsh_fragment in "${ZDOTDIR:-$HOME/.config/zsh}"/zsh.d/[0-9][0-9]-*.zsh(N); do
  source "$_zsh_fragment"
done
[[ -r "${ZDOTDIR:-$HOME/.config/zsh}/99-local.zsh" ]] && source "${ZDOTDIR:-$HOME/.config/zsh}/99-local.zsh"
unset _zsh_fragment
