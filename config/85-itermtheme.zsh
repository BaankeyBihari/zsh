# itermtheme — ephemeral iTerm2 color-scheme switcher.
#
# Recolors the *current* iTerm2 session live by sourcing a "dynamic-colors" script
# from mbadolato/iTerm2-Color-Schemes. Those scripts just printf OSC \033]P<n>
# escapes that rewrite the 16-colour ANSI palette — no plist write, no iTerm2
# restart, no import. Files are cached under $TMPDIR, which the OS clears on reboot,
# so a reboot falls back to your iTerm2 profile default automatically.
#
# Scope is per-shell: each new shell starts at the profile default; `next`/`prev`
# track the active scheme via a shell-local variable only.
#
#   itermtheme <name>    apply a scheme by name (case-insensitive, spaces ok)
#   itermtheme           fzf picker (falls back to `list` without fzf/TTY)
#   itermtheme next|prev cycle through manifest order
#   itermtheme random    apply a random scheme
#   itermtheme list      print available scheme names
#   itermtheme refresh   force re-fetch the name manifest
#
# Note: dynamic-colors set the ANSI palette, not the profile's separate
# background/foreground/cursor colours — it's the only no-restart method.

_ITERMTHEME_REPO="mbadolato/iTerm2-Color-Schemes"
_ITERMTHEME_RAW="https://raw.githubusercontent.com/${_ITERMTHEME_REPO}/master/iterm-dynamic-colors"
_ITERMTHEME_API="https://api.github.com/repos/${_ITERMTHEME_REPO}/contents/iterm-dynamic-colors?per_page=1000"

_itermtheme_cache() { print -r -- "${TMPDIR:-/tmp}/itermtheme"; }

# URL-encode the bits that actually occur in scheme names (spaces); leave the rest.
_itermtheme_urlenc() { print -rn -- "${1// /%20}"; }

# Ensure the name manifest exists; fetch once per reboot. $1=force re-fetch.
_itermtheme_manifest() {
  local dir; dir="$(_itermtheme_cache)"
  local mf="$dir/manifest"
  if [[ "$1" == force ]]; then rm -f "$mf"; fi
  if [[ ! -s "$mf" ]]; then
    command -v curl >/dev/null 2>&1 || { print -u2 "itermtheme: curl not found"; return 1; }
    mkdir -p "$dir"
    local json
    json="$(curl -fsSL --max-time 20 "$_ITERMTHEME_API" 2>/dev/null)" \
      || { print -u2 "itermtheme: could not fetch scheme list (offline?)"; return 1; }
    # Pull "<name>.sh" out of the JSON "name" fields, strip the extension.
    print -r -- "$json" \
      | grep -oE '"name": *"[^"]+\.sh"' \
      | sed -E 's/.*"name": *"(.*)\.sh"/\1/' \
      | sort > "$mf"
    [[ -s "$mf" ]] || { print -u2 "itermtheme: scheme list came back empty"; rm -f "$mf"; return 1; }
  fi
  print -r -- "$mf"
}

# Resolve a user query to an exact scheme name (exact first, then case-insensitive).
_itermtheme_resolve() {
  local query="$1" mf; mf="$(_itermtheme_manifest)" || return 1
  local exact; exact="$(grep -ixF -- "$query" "$mf" | head -n1)"
  [[ -n "$exact" ]] && { print -r -- "$exact"; return 0; }
  local hit; hit="$(grep -iF -- "$query" "$mf" | head -n1)"
  [[ -n "$hit" ]] && { print -r -- "$hit"; return 0; }
  return 1
}

# Download (if needed) and source the dynamic-colors script for an exact name.
_itermtheme_apply() {
  local name="$1" dir; dir="$(_itermtheme_cache)"
  local f="$dir/$name.sh"
  if [[ ! -s "$f" ]]; then
    mkdir -p "$dir"
    curl -fsSL --max-time 20 "$_ITERMTHEME_RAW/$(_itermtheme_urlenc "$name").sh" -o "$f" 2>/dev/null \
      || { print -u2 "itermtheme: failed to download '$name'"; rm -f "$f"; return 1; }
  fi
  source "$f"
  typeset -g _ITERMTHEME_CURRENT="$name"
  print -r -- "itermtheme: $name"
}

itermtheme() {
  [[ "$TERM_PROGRAM" == "iTerm.app" ]] \
    || print -u2 "itermtheme: not running under iTerm2 — palette escapes may be ignored."

  local cmd="${1:-}"
  case "$cmd" in
    list)
      local mf; mf="$(_itermtheme_manifest)" || return 1
      cat "$mf" ;;
    refresh)
      _itermtheme_manifest force >/dev/null && print -r -- "itermtheme: manifest refreshed" ;;
    random)
      local mf; mf="$(_itermtheme_manifest)" || return 1
      local -a all; all=("${(@f)$(<"$mf")}")
      (( ${#all} )) || return 1
      _itermtheme_apply "${all[RANDOM % ${#all} + 1]}" ;;
    next|prev)
      local mf; mf="$(_itermtheme_manifest)" || return 1
      local -a all; all=("${(@f)$(<"$mf")}")
      (( ${#all} )) || return 1
      local i="${all[(ie)$_ITERMTHEME_CURRENT]}"   # 1-based; len+1 if absent
      (( i > ${#all} )) && i=0
      if [[ "$cmd" == next ]]; then (( i = i % ${#all} + 1 )); else (( i = (i - 2 + ${#all}) % ${#all} + 1 )); fi
      _itermtheme_apply "${all[i]}" ;;
    ""|pick)
      local mf; mf="$(_itermtheme_manifest)" || return 1
      if command -v fzf >/dev/null 2>&1 && [[ -t 0 ]]; then
        local choice; choice="$(fzf --prompt='iterm theme> ' --height=40% --reverse < "$mf")"
        [[ -n "$choice" ]] && _itermtheme_apply "$choice"
      else
        cat "$mf"
      fi ;;
    *)
      local name; name="$(_itermtheme_resolve "$*")" \
        || { print -u2 "itermtheme: no scheme matching '$*' (try: itermtheme list)"; return 1; }
      _itermtheme_apply "$name" ;;
  esac
}

# Tab-completion over manifest names (only if already cached — never triggers a fetch).
_itermtheme_complete() {
  local mf="${TMPDIR:-/tmp}/itermtheme/manifest"
  local -a names
  [[ -s "$mf" ]] && names=("${(@f)$(<"$mf")}")
  compadd -- list refresh random next prev pick
  (( ${#names} )) && compadd -- "${names[@]}"
}
compdef _itermtheme_complete itermtheme 2>/dev/null
