# znap: zsh plugin manager. bin/install.sh clones it into $XDG_DATA_HOME/znap.
# If absent (e.g. first interactive shell after a fresh checkout that skipped install.sh),
# clone on demand so a usable shell still comes up.

_ZNAP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/znap"
if [[ ! -r "$_ZNAP_HOME/znap.zsh" ]]; then
  print -u2 "znap not found at $_ZNAP_HOME; attempting clone…"
  # GIT_TERMINAL_PROMPT=0 → fail fast instead of blocking the shell on a credential
  # prompt. If the clone fails (offline at 2 AM), warn and bring the shell up WITHOUT
  # plugins rather than aborting .zshrc and leaving the user with no usable terminal.
  GIT_TERMINAL_PROMPT=0 command git clone --depth=1 \
    https://github.com/marlonrichert/zsh-snap.git "$_ZNAP_HOME" 2>/dev/null
fi
if [[ -r "$_ZNAP_HOME/znap.zsh" ]]; then
  source "$_ZNAP_HOME/znap.zsh"
else
  print -u2 "znap unavailable; starting without plugins. Run ~/zsh/bin/install.sh when online."
fi
unset _ZNAP_HOME
