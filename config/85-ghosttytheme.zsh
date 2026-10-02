# ghosttytheme — Ghostty color-scheme switcher.
#
# Writes `theme = <name>` to an unmanaged `theme` file next to the repo-managed
# config.ghostty (which pulls it in via `config-file = ?theme`, so a theme change is
# never drift) and sends SIGUSR2 so all open Ghostty windows reload. Changes persist across restarts (Ghostty has no
# stateless palette-escape equivalent).
#
#   ghosttytheme <name>    apply a theme by name (case-insensitive prefix ok)
#   ghosttytheme           fzf picker with live preview as you navigate
#   ghosttytheme next|prev cycle through the built-in theme list
#   ghosttytheme random    apply a random theme
#   ghosttytheme list      print available theme names

_GHOSTTYTHEME_CFG="${GHOSTTY_CONFIG:-$HOME/Library/Application Support/com.mitchellh.ghostty/theme}"

# Strip ANSI codes in case `ghostty +list-themes` adds colour in future versions, and the
# trailing " (resources)"/" (user)" source tag it prints — it is not part of the theme name.
_ghosttytheme_list() {
  ghostty +list-themes 2>/dev/null | sed $'s/\x1b\\[[0-9;]*m//g' \
    | sed -E 's/ \((resources|user)\)$//' | grep -v '^[[:space:]]*$'
}

_ghosttytheme_current() {
  grep -E '^theme[[:space:]]*=' "$_GHOSTTYTHEME_CFG" 2>/dev/null \
    | sed -E 's/^theme[[:space:]]*=[[:space:]]*//' | tail -n1
}

_ghosttytheme_write() {
  local name="$1"
  if grep -qE '^theme[[:space:]]*=' "$_GHOSTTYTHEME_CFG" 2>/dev/null; then
    sed -i '' -E "s|^theme[[:space:]]*=.*|theme = $name|" "$_GHOSTTYTHEME_CFG"
  else
    print -r -- "theme = $name" >> "$_GHOSTTYTHEME_CFG"
  fi
}

_ghosttytheme_reload() { pkill -SIGUSR2 ghostty 2>/dev/null || true; }

_ghosttytheme_apply() {
  _ghosttytheme_write "$1"
  _ghosttytheme_reload
  print -r -- "ghosttytheme: $1"
}

# Materialize a small helper script that fzf's execute-silent can call.
# Functions aren't available in fzf subshells, and passing theme names with
# spaces via shell substitution in the bind string is fragile — the helper
# reads the focused name from a temp file written by fzf's printf action.
_ghosttytheme_helper() {
  local f="${TMPDIR:-/tmp}/.ghosttytheme_apply"
  if [[ ! -x "$f" ]]; then
    local cfg="$_GHOSTTYTHEME_CFG"
    cat > "$f" <<HELPER
#!/bin/sh
name="\$(cat /tmp/.ghosttytheme_focus 2>/dev/null)" || exit 0
cfg='$cfg'
if grep -qE '^theme[[:space:]]*=' "\$cfg" 2>/dev/null; then
  sed -i '' -E "s|^theme[[:space:]]*=.*|theme = \$name|" "\$cfg"
else
  printf 'theme = %s\n' "\$name" >> "\$cfg"
fi
pkill -SIGUSR2 ghostty 2>/dev/null || true
HELPER
    chmod +x "$f"
  fi
  print -r -- "$f"
}

ghosttytheme() {
  local cmd="${1:-}"
  case "$cmd" in
    list)
      _ghosttytheme_list ;;
    random)
      local -a all; all=("${(@f)$(_ghosttytheme_list)}")
      (( ${#all} )) || return 1
      _ghosttytheme_apply "${all[RANDOM % ${#all} + 1]}" ;;
    next|prev)
      local -a all; all=("${(@f)$(_ghosttytheme_list)}")
      (( ${#all} )) || return 1
      local cur; cur="$(_ghosttytheme_current)"
      local i="${all[(ie)$cur]}"
      (( i > ${#all} )) && i=0
      if [[ "$cmd" == next ]]; then
        (( i = i % ${#all} + 1 ))
      else
        (( i = (i - 2 + ${#all}) % ${#all} + 1 ))
      fi
      _ghosttytheme_apply "${all[i]}" ;;
    ""|pick)
      if command -v fzf >/dev/null 2>&1 && [[ -t 0 ]]; then
        local cur; cur="$(_ghosttytheme_current)"
        local helper; helper="$(_ghosttytheme_helper)"
        local choice
        choice="$(_ghosttytheme_list | fzf \
          --prompt='ghostty theme> ' \
          --height=40% \
          --reverse \
          --query="$cur" \
          --bind "focus:execute-silent(printf '%s' {} > /tmp/.ghosttytheme_focus && $helper)")"
        if [[ -n "$choice" ]]; then
          _ghosttytheme_apply "$choice"
        elif [[ -n "$cur" ]]; then
          # Cancelled — restore the theme that was active before the picker opened.
          _ghosttytheme_write "$cur" && _ghosttytheme_reload
        fi
      else
        _ghosttytheme_list
      fi ;;
    *)
      local name
      name="$(_ghosttytheme_list | grep -iF -- "$*" | head -n1)"
      [[ -n "$name" ]] || {
        print -u2 "ghosttytheme: no theme matching '$*' (try: ghosttytheme list)"
        return 1
      }
      _ghosttytheme_apply "$name" ;;
  esac
}

_ghosttytheme_complete() {
  local -a names
  names=("${(@f)$(_ghosttytheme_list 2>/dev/null)}")
  compadd -- list random next prev pick
  (( ${#names} )) && compadd -- "${names[@]}"
}
compdef _ghosttytheme_complete ghosttytheme 2>/dev/null
