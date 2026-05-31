# $PATH composition. brew shellenv already ran in ~/.zshenv; this layers user-local
# and tool-manager paths on top, then de-duplicates.

path=("$HOME/.local/bin" $path)

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)

typeset -U path
export PATH
