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
# Some terminals/shell integrations re-derive the title every prompt, which would wipe
# a one-shot escape. So we register a precmd hook that re-asserts the chosen title
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

# logit — run a command, tee stdout+stderr live to the terminal AND to a markdown
# file ready to @-reference in a Claude Code session (or feed any other tool).
# By default each line is timestamped and labelled by stream —
# `[2026-07-11 14:03:22] [STDERR] msg` — via process substitution, so stderr stays
# on the terminal's stderr; -p (plain) restores the old unlabelled 2>&1 merge.
# Files land in ${XDG_CACHE_HOME:-~/.cache}/captures/YYYY-MM-DD-<slug>.md — cache on
# purpose: the XDG spec marks it deletable-anytime, and each run additionally prunes
# captures older than 30 days, so nothing dangles eating disk. Exit code of the wrapped
# command is preserved ($? — pipestatus in plain mode), so `logit cmd && next` works.
#
#   logit pytest -x            # → …/captures/2026-07-11-pytest.md
#   logit -p make build        # plain: merged, no timestamps/labels
#   logit -n api-smoke curl …  # explicit slug instead of the derived one
#   logit -l                   # print the newest capture's path

# Per-line annotator for logit: prefix each line with a timestamp + stream tag.
# Pure zsh — strftime comes from the zsh/datetime module, no gawk/moreutils needed.
# The post-loop check salvages a final line that lacks a trailing newline.
_logit_label() {  # $1 = STDOUT|STDERR
  local line ts
  zmodload zsh/datetime
  while IFS= read -r line; do
    strftime -s ts '%F %T'
    print -r -- "[$ts] [$1] $line"
  done
  [[ -n "$line" ]] && { strftime -s ts '%F %T'; print -r -- "[$ts] [$1] $line" }
}

# toggle-headroom — flip the shell between routed (through the local Headroom
# proxy) and direct. Toggles ANTHROPIC_BASE_URL / OPENAI_BASE_URL based on
# whether ANTHROPIC_BASE_URL is currently set — no argument needed.
#
#   toggle-headroom   # unset → export both (port from $HEADROOM_PORT, default 8787)
#   toggle-headroom   # set → unset both
toggle-headroom() {
  if [[ -n "$ANTHROPIC_BASE_URL" ]]; then
    unset ANTHROPIC_BASE_URL OPENAI_BASE_URL
    echo "headroom: off"
  else
    local port="${HEADROOM_PORT:-8787}"
    export ANTHROPIC_BASE_URL="http://127.0.0.1:$port"
    export OPENAI_BASE_URL="http://127.0.0.1:$port/v1"
    echo "headroom: on ($ANTHROPIC_BASE_URL)"
  fi
}

# claude — wrapper that routes the CLI through the local Headroom proxy. Unlike
# toggle-headroom (whole shell, manual), this guards claude specifically: it
# checks the proxy is ready and sets ANTHROPIC_BASE_URL for the claude process
# only (OPENAI_BASE_URL is a codex concern, not claude's). Proxy down => print
# `headroom install status` and abort (never launches claude unrouted). Escape
# hatch: HEADROOM_OFF=1 claude  runs direct, no check. --version/--help skip it.
claude() {
  [[ -n "$HEADROOM_OFF" ]] && { command claude "$@"; return; }
  case "$1" in
    -v|--version|-h|--help) command claude "$@"; return ;;
  esac
  local port="${HEADROOM_PORT:-8787}"
  if ! curl -fsS --connect-timeout 1 --max-time 2 "http://127.0.0.1:$port/readyz" >/dev/null 2>&1; then
    print -ru2 -- "headroom proxy down (http://127.0.0.1:$port/readyz) — claude launch aborted"
    print -ru2 -- "--- headroom install status ---"
    headroom install status >&2
    print -ru2 -- "fix: 'headroom install start' if stopped, or"
    print -ru2 -- "     'headroom install apply --preset persistent-service --providers auto' if not deployed"
    return 1
  fi
  ANTHROPIC_BASE_URL="http://127.0.0.1:$port" command claude "$@"
}

# bentopdf — manage the BentoPDF Docker service (local PDF toolkit at localhost:3000).
# Container run with --restart unless-stopped, so once started it survives
# reboots/Docker restarts on its own; these subcommands are for manual control.
#
#   bentopdf start   # create (first run) or (re)start the container
#   bentopdf stop    # stop the container, restart policy left in place
#   bentopdf update  # pull latest image, recreate container
#   bentopdf status  # docker ps filtered to this container
bentopdf() {
  if ! command -v docker >/dev/null 2>&1; then
    print -u2 "bentopdf: docker not installed"
    return 127
  fi
  local name="bentopdf-service" image="bentopdf/bentopdf:latest"
  case "$1" in
    start)
      if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
        docker start "$name"
      else
        docker run -d --name "$name" --restart unless-stopped -p 3000:80 "$image"
      fi
      ;;
    stop)
      docker stop "$name"
      ;;
    update)
      docker pull "$image"
      docker rm -f "$name" 2>/dev/null
      docker run -d --name "$name" --restart unless-stopped -p 3000:80 "$image"
      ;;
    status)
      docker ps -a --filter "name=$name"
      ;;
    *)
      print -u2 "usage: bentopdf start|stop|update|status"
      return 2
      ;;
  esac
}

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

  local slug="" plain=0
  while (( $# )); do
    case "$1" in
      -p) plain=1; shift ;;
      -n)
        [[ -n "${2:-}" ]] || { print -u2 "logit: -n needs a slug"; return 2 }
        slug="$2"; shift 2
        ;;
      *) break ;;
    esac
  done
  (( $# )) || { print -u2 "usage: logit [-p] [-n slug] cmd [args…]   |   logit -l"; return 2 }

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
  local rc
  if (( plain )); then
    "$@" 2>&1 | tee -a "$file"
    rc=${pipestatus[1]}
  else
    # The { } wrapper matters: zsh only waits for process substitutions attached to
    # a complex command, and the footer below must not race ahead of the tees.
    { "$@"; } \
      1> >(_logit_label STDOUT | tee -a "$file") \
      2> >(_logit_label STDERR | tee -a "$file" >&2)
    rc=$?
  fi
  printf '````\n\nexit code: %d\n' "$rc" >> "$file"
  print -u2 "→ saved: ${file/#$HOME/~}"
  return $rc
}
