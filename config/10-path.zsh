# $PATH composition. brew shellenv already ran in ~/.zshenv; this layers user-local
# and tool-manager paths on top, then de-duplicates.

# Re-assert Homebrew ahead of system paths. macOS /etc/zprofile runs path_helper AFTER
# ~/.zshenv on login shells, which shuffles /opt/homebrew/bin back behind /usr/bin (it
# lives in /etc/paths.d/homebrew, which path_helper appends last). Prepend it here, in the
# interactive zshrc post-path_helper; typeset -U below drops the stale tail copy.
[[ -n "$HOMEBREW_PREFIX" ]] && path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)

path=("$HOME/.local/bin" $path)

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)

[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)

typeset -U path
export PATH
