# $PATH composition. brew shellenv already ran in ~/.zshenv; this layers user-local
# and tool-manager paths on top, then de-duplicates.

path=("$HOME/.local/bin" $path)

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)

# NOTE: Antigravity / Gemini CLI paths intentionally omitted. Antigravity refactored
# into separate apps (Antigravity + Antigravity IDE) and the old
# ~/.antigravity/antigravity/bin symlinks are now dangling. Re-add a working bin dir
# here once a proper install is in place.

typeset -U path
export PATH
