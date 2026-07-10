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

# benchmark — hyperfine with a sane default warmup so first-run cache effects don't
# skew the comparison. All arguments pass straight through. hyperfine errors on a
# repeated --warmup, so the default is added only when the caller didn't supply one.
#
#   benchmark 'zsh -i -c exit' 'bash -i -c exit'
#   benchmark --warmup 10 'cmd'      # your value used; default 3 not added
benchmark() {
  if ! command -v hyperfine >/dev/null 2>&1; then
    print -u2 "benchmark: hyperfine not installed (run bin/install.sh)"
    return 127
  fi
  local a
  for a in "$@"; do
    if [[ "$a" == "-w" || "$a" == "--warmup" || "$a" == --warmup=* ]]; then
      hyperfine "$@"
      return
    fi
  done
  hyperfine --warmup 3 "$@"
}

# logit — run a command, tee merged stdout+stderr live to the terminal AND to a
# markdown file ready to @-reference in a Claude Code session (or feed any other tool).
# Files land in ${XDG_CACHE_HOME:-~/.cache}/captures/YYYY-MM-DD-<slug>.md — cache on
# purpose: the XDG spec marks it deletable-anytime, and each run additionally prunes
# captures older than 30 days, so nothing dangles eating disk. Exit code of the wrapped
# command is preserved (pipestatus), so `logit cmd && next` still works.
#
#   logit pytest -x            # → …/captures/2026-07-11-pytest.md
#   logit -n api-smoke curl …  # explicit slug instead of the derived one
#   logit -l                   # print the newest capture's path
logit() {
  local keep_days=30
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/captures"

  if [[ "${1:-}" == "-l" ]]; then
    local -a latest
    latest=("$dir"/*.md(N.om))
    if (( $#latest )); then
      print -r -- "${latest[1]}"
      return 0
    fi
    print -u2 "logit: no captures in $dir"
    return 1
  fi

  local slug=""
  if [[ "${1:-}" == "-n" ]]; then
    [[ -n "${2:-}" ]] || { print -u2 "logit: -n needs a slug"; return 2 }
    slug="$2"; shift 2
  fi
  (( $# )) || { print -u2 "usage: logit [-n slug] cmd [args…]   |   logit -l"; return 2 }

  # Derive slug from the command word (+ first non-flag arg): `git diff` → git-diff.
  if [[ -z "$slug" ]]; then
    slug="${1:t}"
    [[ -n "${2:-}" && "${2:-}" != -* ]] && slug+="-$2"
  fi
  slug="${slug//[^A-Za-z0-9._-]/-}"

  mkdir -p "$dir"
  # Self-prune BEFORE writing, so the new capture can't be collateral.
  find "$dir" -name '*.md' -type f -mtime +$keep_days -delete 2>/dev/null

  local file="$dir/$(date +%F)-$slug.md"
  [[ -e "$file" ]] && file="$dir/$(date +%F)-$slug-$(date +%H%M%S).md"

  # Four-backtick fence so captured output containing ``` can't break the block.
  {
    printf '# logit: %s\n\n' "$*"
    printf -- '- cwd: `%s`\n- date: %s\n\n````\n' "$PWD" "$(date '+%F %T')"
  } > "$file"
  "$@" 2>&1 | tee -a "$file"
  local rc=${pipestatus[1]}
  printf '````\n\nexit code: %d\n' "$rc" >> "$file"
  print -u2 "→ saved: ${file/#$HOME/~}"
  return $rc
}
