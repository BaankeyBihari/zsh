# Keychain-backed env vars, driven by ~/.config/tokens/map.yaml (ENV_NAME: keychain service).
# Two sections: `managed:` (written by bin/install.sh) and `unmanaged:` (yours, never touched).
# Entries are 2-space indented, either `NAME: service` or nested with an optional validator:
#     NAME:
#       service: keychain-service
#       validator: any shell command or script; exit 0 = token is good (run by `tokens validate`)
# Only that flat subset of YAML is understood. No literal secrets live in the map, just names.

# _tokens_map — fill _TOKENS_MAP (name -> service), _TOKENS_SECT (name -> section) and
# _TOKENS_VAL (name -> validator, only when set). `unmanaged` replaces a `managed` entry of the
# same name entirely, validator included. Missing file is a silent no-op.
_tokens_map() {
  typeset -gA _TOKENS_MAP _TOKENS_SECT _TOKENS_VAL
  _TOKENS_MAP=() _TOKENS_SECT=() _TOKENS_VAL=()
  local file="${XDG_CONFIG_HOME:-$HOME/.config}/tokens/map.yaml" line sect= cur= key v
  [[ -r "$file" ]] || return 0
  while IFS= read -r line; do
    case "$line" in
      managed:*)   sect=managed; cur=; continue ;;
      unmanaged:*) sect=unmanaged; cur=; continue ;;
    esac
    [[ -n "$sect" ]] || continue
    if [[ "$line" =~ '^  ([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*([^[:space:]#]*)' ]]; then
      cur=$match[1]
      if [[ "$sect" == managed && "${_TOKENS_SECT[$cur]}" == unmanaged ]]; then
        cur=; continue
      fi
      _TOKENS_MAP[$cur]=$match[2]
      _TOKENS_SECT[$cur]=$sect
      unset "_TOKENS_VAL[$cur]"
    elif [[ -n "$cur" && "$line" =~ '^    +(service|validator):[[:space:]]*(.*)$' ]]; then
      key=$match[1] v=$match[2]
      v="${v%"${v##*[![:space:]]}"}"
      (( ${#v} >= 2 )) && [[ "$v" == \"*\" || "$v" == \'*\' ]] && v="${v[2,-2]}"
      if [[ "$key" == service ]]; then _TOKENS_MAP[$cur]=$v
      elif [[ -n "$v" ]]; then _TOKENS_VAL[$cur]=$v; fi
    fi
  done < "$file"
}

_tokens_map
for _tok in ${(k)_TOKENS_MAP}; do
  [[ -n "${_TOKENS_MAP[$_tok]}" ]] || continue
  export "$_tok=$(security find-generic-password -a "$USER" -s "${_TOKENS_MAP[$_tok]}" -w 2>/dev/null)"
done
unset _tok
