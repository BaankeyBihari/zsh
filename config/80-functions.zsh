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
