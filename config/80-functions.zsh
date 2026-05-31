# Conda activation is heavy and clashes with pyenv. Load it only on explicit request
# via `loadconda`, so every shell doesn't pay the cost.
loadconda() {
  local root
  for root in /opt/homebrew/Caskroom/miniconda/base /opt/homebrew/anaconda3; do
    [[ -d "$root" ]] || continue
    local __conda_setup
    __conda_setup="$("$root/bin/conda" shell.zsh hook 2>/dev/null)" && {
      eval "$__conda_setup"
      unset __conda_setup
      return 0
    }
    if [[ -f "$root/etc/profile.d/conda.sh" ]]; then
      . "$root/etc/profile.d/conda.sh"
      return 0
    fi
    export PATH="$root/bin:$PATH"
    return 0
  done
  print -u2 "loadconda: no conda found (looked under /opt/homebrew/Caskroom/miniconda and /opt/homebrew/anaconda3)"
  return 1
}

# gCloner — clone a repo into <repoName>/<branch>. Branch defaults to main.
# Ported from the legacy ~/.zprofile so it lives under version control.
gCloner() {
  local repoUrl="$1"
  local branchName="${2:-main}"
  local repoName
  repoName="$(basename -s .git "$repoUrl")"
  git clone --branch "$branchName" "$repoUrl" "$repoName/$branchName"
}

# rename-tab — set a sticky title on the current terminal tab/window.
# Uses OSC 1 (tab/icon) + OSC 2 (window) escape codes, which iTerm2, Terminal.app,
# and xterm-compatible emulators honour. printf (not print -P) so the title is
# taken literally — no prompt/% expansion of user input.
#
# iTerm2's shell integration re-derives the title every prompt, which would wipe a
# one-shot escape. So we register a precmd hook that re-asserts the chosen title
# until you clear it. Call with no argument to release the tab back to the default.
#
#   rename-tab deploy      # tab now reads "deploy" and stays that way
#   rename-tab "api logs"  # spaces are fine
#   rename-tab             # clear — auto-title resumes
_rename_tab_apply() { printf '\e]1;%s\a\e]2;%s\a' "$__TAB_TITLE" "$__TAB_TITLE"; }
rename-tab() {
  autoload -Uz add-zsh-hook
  if [[ $# -eq 0 ]]; then
    unset __TAB_TITLE
    add-zsh-hook -d precmd _rename_tab_apply 2>/dev/null
    return 0
  fi
  typeset -g __TAB_TITLE="$*"
  add-zsh-hook precmd _rename_tab_apply   # re-assert each prompt (idempotent)
  _rename_tab_apply                        # and apply right now
}
