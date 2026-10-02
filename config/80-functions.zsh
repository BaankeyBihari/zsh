# manigen — clone repos flat into the cwd, then (re)generate mani.yaml from every
# git dir found there (except Work/, which holds worktrees, not projects). Rolls
# up the old gCloner: pass repo URLs to clone before the scan, or none to just
# rescan after adding/removing a repo by hand. Existing repoName dirs are left
# alone (idempotent — safe to re-run after a manual `git clone`/`git init`).
#
#   manigen                                  # rescan cwd only
#   manigen git@github.com:org/repo.git ...  # clone (main, falling back to
#                                             # whatever default branch), then scan
manigen() {
  local repoUrl repoName
  for repoUrl in "$@"; do
    repoName="$(basename -s .git "$repoUrl")"
    if [[ -d "$repoName" ]]; then
      print "manigen: skipping $repoName (already exists)"
    else
      print "manigen: cloning $repoName"
      git clone --branch main "$repoUrl" "$repoName" 2>/dev/null || git clone "$repoUrl" "$repoName"
    fi
  done

  local dir count=0
  {
    print "import:"
    print "  - ~/.config/mani/tasks.yaml"
    print ""
    print "projects:"
    for dir in */; do
      dir="${dir%/}"
      [[ "$dir" == "Work" ]] && continue
      [[ -d "$dir/.git" ]] || continue
      print "  $dir:"
      print "    path: ./$dir"
      (( count++ ))
    done
  } > mani.yaml

  print "manigen: wrote mani.yaml ($count projects)"
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

# _tmux_attach_or_run — shared by claude/codex: resume a matching tmux session
# for this directory if one exists, else start a new one running $cmd there.
# Match = same tool (session name prefixed "$tool-") + same target path: git
# repos match by `git rev-parse --show-toplevel` (any subdirectory finds the
# session rooted at the repo), everything else by ${PWD:A} (resolved, so a
# symlinked path like macOS's /tmp -> /private/tmp still matches tmux's own
# physical pane_current_path). tmux tracks each pane's live cwd itself, so no
# manual path-tagging is needed.
# 0 matches -> new session. 1 -> attach. 2+ -> pick via fzf. No tmux installed
# -> run $cmd directly, same as before this existed. Already inside tmux ($TMUX)
# -> also run $cmd directly, in the current pane: that is how an agent starts in
# a split pane instead of switching to another session. The scan-then-create
# window is flock'd per tool+dir (zsh/system, no new dependency) so two
# near-simultaneous launches from the same place resume each other instead of
# both creating a session -- lock lives in $TMPDIR, not $HOME: it's only
# needed for this instant, nothing to clean up afterward.
_tmux_attach_or_run() {
  local tool="$1" cmd="$2"
  if ! command -v tmux >/dev/null 2>&1 || [[ -n "$TMUX" ]]; then
    eval "$cmd"
    return
  fi
  local target
  target="$(git rev-parse --show-toplevel 2>/dev/null)" || target="${PWD:A}"

  local -a matches
  local name lockfd
  {
    zmodload zsh/system
    local lockfile="${TMPDIR:-/tmp}/tmux-attach-$tool-${target//[^A-Za-z0-9_-]/-}.lock"
    : >> "$lockfile" 2>/dev/null   # zsystem flock needs the file to already exist
    zsystem flock -f lockfd "$lockfile"

    local sess cwd
    while IFS=$'\t' read -r sess cwd; do
      [[ "$sess" == "$tool"-* && "$cwd" == "$target" ]] && matches+=("$sess")
    done < <(tmux list-panes -a -F '#{session_name}	#{pane_current_path}' 2>/dev/null)
    matches=(${(u)matches})

    if (( $#matches == 1 )); then
      name="$matches[1]"
    elif (( $#matches > 1 )); then
      name="$(printf '%s\n' "${matches[@]}" | fzf --prompt="$tool session> ")"
    else
      local base="${target:t}"
      base="${base//[^A-Za-z0-9_-]/-}"
      name="$tool-$base"
      local i=2
      while tmux has-session -t "=$name" 2>/dev/null; do
        name="$tool-$base-$i"
        (( i++ ))
      done
      tmux new-session -d -s "$name" -c "$target" "$cmd"
    fi
  } always {
    exec {lockfd}>&- 2>/dev/null
  }
  [[ -n "$name" ]] || return 1

  tmux attach -t "$name"
}

# claude — wrapper that routes the CLI through the local Headroom proxy. Unlike
# toggle-headroom (whole shell, manual), this guards claude specifically: it
# checks the proxy is ready and sets ANTHROPIC_BASE_URL for the claude process
# only (OPENAI_BASE_URL is a codex concern, not claude's). Proxy down => print
# `headroom install status` and abort (never launches claude unrouted). Once
# routed, launch goes through _tmux_attach_or_run: resumes the matching tmux
# session for this directory if one's running, else starts one. Escape hatch:
# HEADROOM_OFF=1 claude  runs direct, no check, no tmux. --version/--help skip it.
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
  _tmux_attach_or_run claude "ANTHROPIC_BASE_URL=http://127.0.0.1:$port command claude ${(q)@}"
}

# codex — same guarded Headroom routing as claude, using the proxy's OpenAI
# endpoint, and the same tmux session resume/create via _tmux_attach_or_run.
# HEADROOM_OFF=1 bypasses it (no proxy, no tmux); --version/--help stay direct.
codex() {
  [[ -n "$HEADROOM_OFF" ]] && { command codex "$@"; return; }
  case "$1" in
    -v|--version|-h|--help) command codex "$@"; return ;;
  esac
  local port="${HEADROOM_PORT:-8787}"
  if ! curl -fsS --connect-timeout 1 --max-time 2 "http://127.0.0.1:$port/readyz" >/dev/null 2>&1; then
    print -ru2 -- "headroom proxy down (http://127.0.0.1:$port/readyz) — codex launch aborted"
    print -ru2 -- "--- headroom install status ---"
    headroom install status >&2
    print -ru2 -- "fix: 'headroom install start' if stopped, or"
    print -ru2 -- "     'headroom install apply --preset persistent-service --providers auto' if not deployed"
    return 1
  fi
  _tmux_attach_or_run codex "OPENAI_BASE_URL=http://127.0.0.1:$port/v1 command codex ${(q)@}"
}

# agy — Antigravity CLI, tmux session resume/create via _tmux_attach_or_run. No
# Headroom routing (no known base-URL knob for agy), so no proxy check.
# HEADROOM_OFF=1 bypasses tmux; --version/--help and non-interactive -p/--print
# (and its --prompt alias) and subcommands stay direct.
agy() {
  [[ -n "$HEADROOM_OFF" ]] && { command agy "$@"; return; }
  case "$1" in
    -v|--version|-h|--help|-p|--print|--prompt|agent|agents|changelog|help) command agy "$@"; return ;;
  esac
  _tmux_attach_or_run agy "command agy ${(q)@}"
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
        docker run -d --name "$name" --restart unless-stopped -p 3000:8080 "$image"
      fi
      ;;
    stop)
      docker stop "$name"
      ;;
    update)
      docker pull "$image"
      docker rm -f "$name" 2>/dev/null
      docker run -d --name "$name" --restart unless-stopped -p 3000:8080 "$image"
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

# tokens — view or update the keychain-backed secrets listed in
# ~/.config/tokens/map.yaml (loaded by config/65-tokens.zsh). `list` shows each var
# masked to its last 4 chars (or "not set") and its map section; `show NAME` prints one
# token's full value; `set NAME` prompts (hidden input) and writes the keychain entry,
# then exports it into the current shell; `validate [NAME]` runs each token's `validator`
# from the map (a shell command or script, exit 0 = good; output hidden) and warns for
# tokens that have none.
#
#   tokens              # same as `tokens list`
#   tokens show HF_TOKEN
#   tokens set HF_TOKEN
#   tokens validate [HF_TOKEN]
tokens() {
  _tokens_map
  if (( ! $#_TOKENS_MAP )); then
    print -u2 "tokens: no entries in ${XDG_CONFIG_HOME:-$HOME/.config}/tokens/map.yaml"
    return 1
  fi
  case "$1" in
    list|"")
      local name val
      for name in "${(@ok)_TOKENS_MAP}"; do
        val="${(P)name}"
        if [[ -n "$val" ]]; then
          print -r -- "$name: ...${val: -4} (${_TOKENS_SECT[$name]})"
        else
          print -r -- "$name: not set (${_TOKENS_SECT[$name]})"
        fi
      done
      ;;
    show)
      local name="$2"
      [[ -n "${_TOKENS_MAP[$name]}" ]] || { print -u2 "tokens: unknown token '$name' (${(ok)_TOKENS_MAP})"; return 2 }
      print -r -- "${(P)name}"
      ;;
    set)
      local name="$2"
      [[ -n "${_TOKENS_MAP[$name]}" ]] || { print -u2 "tokens: unknown token '$name' (${(ok)_TOKENS_MAP})"; return 2 }
      local value
      read -rs "value?tokens: enter value for $name: "
      print
      [[ -n "$value" ]] || { print -u2 "tokens: empty input, $name left unchanged"; return 1 }
      security add-generic-password -a "$USER" -s "${_TOKENS_MAP[$name]}" -w "$value" -U
      export "$name=$value"
      print "tokens: updated $name"
      ;;
    validate)
      local -a names
      local name val vrc rc=0
      if [[ -n "$2" ]]; then
        [[ -n "${_TOKENS_MAP[$2]}" ]] || { print -u2 "tokens: unknown token '$2' (${(ok)_TOKENS_MAP})"; return 2 }
        names=("$2")
      else
        names=("${(@ok)_TOKENS_MAP}")
      fi
      for name in "${names[@]}"; do
        val="${(P)name}"
        if [[ -z "$val" ]]; then
          print -r -- "$name: not set"; rc=1
        elif [[ -z "${_TOKENS_VAL[$name]}" ]]; then
          print -u2 "$name: no validator configured"
        elif env "$name=$val" sh -c "${_TOKENS_VAL[$name]}" >/dev/null 2>&1; then
          print -r -- "$name: ok"
        else
          vrc=$?; print -r -- "$name: FAILED (exit $vrc)"; rc=1
        fi
      done
      return $rc
      ;;
    *)
      print -u2 "usage: tokens [list|show <name>|set <name>|validate [name]]"
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

# cheat — keys/aliases/functions quick reference. Static text: update it when the
# bindings in tmux/tmux.conf, ghostty/config.ghostty or 70-aliases.zsh change.
#   cheat            # everything
#   cheat keys|aliases|funcs|work
cheat() {
  local sec="${1:-all}"
  case "$sec" in all|keys|aliases|funcs|work) ;; *) print -u2 "usage: cheat [keys|aliases|funcs|work]"; return 2 ;; esac

  if [[ $sec == (all|keys) ]]; then
    command cat <<'EOS'
GHOSTTY (inside tmux; split/pane chords just send the tmux prefix C-b + key)
  cmd+d then s        split right            (tmux prefix |)
  cmd+d then v        split down             (tmux prefix -)
  cmd+alt+arrows      move between panes     (tmux prefix + arrow)
  cmd+shift+f         zoom/unzoom pane       (tmux prefix z)
  cmd+shift+e         spread panes evenly    (tmux prefix E)
  cmd+t / cmd+w       new tab / close surface
  cmd+shift+left/right  previous / next Ghostty tab
  cmd+`               quick terminal (global)

TMUX (prefix = C-b; new panes open in the current directory)
  prefix |  /  -      split right / down
  prefix arrows       select pane
  prefix z            zoom pane          prefix E  spread evenly
  prefix c            new window         prefix n / p  next / previous window
  prefix d            detach (claude/codex/agy sessions resume on relaunch)
  prefix [            copy mode (q quits)
  mouse               click pane/window, drag border to resize, wheel scrolls,
                      drag-select copies (hold Option to bypass tmux)

SHELL (fzf)
  Ctrl-R              fuzzy history      Ctrl-T  fuzzy file insert
  Alt-C               fuzzy cd

EOS
  fi
  if [[ $sec == (all|aliases) ]]; then
    command cat <<'EOS'
ALIASES
  ls ll la l tree     eza (icons; ll adds git status)
  cat                 bat
  c                   clear
  j                   zoxide jump (z <dir>, zi = interactive)

EOS
  fi
  if [[ $sec == (all|funcs) ]]; then
    command cat <<'EOS'
FUNCTIONS
  cheat [keys|aliases|funcs|work]   this help
  manigen <url…>      clone repos flat, refresh mani.yaml (no args = rescan)
  rename-tab <name>   set terminal tab title
  benchmark <cmd…>    hyperfine with warmup
  logit [-p] [-n slug] <cmd…>  capture output to ~/.cache/captures; logit -l = newest
  toggle-headroom     route Anthropic/OpenAI via the Headroom proxy; again = unset
  claude codex agy    tmux-backed, resumable (HEADROOM_OFF=1 = direct)
  tokens [list|show|set <name>|validate [name]]  keychain-backed API tokens
  bentopdf start|stop|update|status  PDF tool container
  ghosttytheme        pick Ghostty theme
EOS
  fi
  if [[ $sec == (all|work) ]]; then
    command cat <<'EOS'

WORKFLOW (mani acts across repos, gita shows status; tasks in ~/.config/mani/tasks.yaml)
  Run mani from the folder holding mani.yaml (see manigen); --all = every project.
  1 morning     mani run sync --all                     pull default branch everywhere
                                                        (gita group = <workspace folder>-reference)
                gita ll <workspace>-reference          base repos: clean / up to date?
  2 new ticket  mani run create-work slug=T-1 --all     Work/Work-<workspace>-T-1/<repo>,
                                                        upstream set, gita group <workspace>-T-1
  3 dashboard   gita ll <workspace>-T-1                 * modified  + staged  ahead/behind
  4 update      mani run rebase-work slug=T-1 --all     rebase on default (halts on conflict)
                mani run push-work slug=T-1 --all       push every worktree
                mani run pull-work slug=T-1 --all       pull --ff-only
  5 teardown    mani run clean-work slug=T-1 --all      refuses dirty / unpushed repos; drops gita entries
                mani run clean-work-forced slug=T-1 --all   DESTROYS unpushed work
  gita ll         all repos          gita ll <workspace>-reference   base repos only
EOS
  fi
}
