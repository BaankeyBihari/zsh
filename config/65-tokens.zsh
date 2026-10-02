# Keychain-backed env vars, driven by ~/.config/tokens/map.yaml (ENV_NAME: keychain service).
# Two sections: `managed:` (written by bin/install.sh) and `unmanaged:` (yours, never touched).
# Only that flat subset of YAML is understood. No literal secrets live in the map, just names.

# _tokens_map — fill _TOKENS_MAP (name -> service) and _TOKENS_SECT (name -> section).
# `unmanaged` wins over `managed` on a name clash. Missing file is a silent no-op.
_tokens_map() {
  typeset -gA _TOKENS_MAP _TOKENS_SECT
  _TOKENS_MAP=() _TOKENS_SECT=()
  local file="${XDG_CONFIG_HOME:-$HOME/.config}/tokens/map.yaml" line sect=
  [[ -r "$file" ]] || return 0
  while IFS= read -r line; do
    case "$line" in
      managed:*)   sect=managed; continue ;;
      unmanaged:*) sect=unmanaged; continue ;;
    esac
    [[ -n "$sect" ]] || continue
    if [[ "$line" =~ '^[[:space:]]+([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*([^[:space:]#]+)' ]]; then
      [[ "$sect" == managed && "${_TOKENS_SECT[$match[1]]}" == unmanaged ]] && continue
      _TOKENS_MAP[$match[1]]=$match[2]
      _TOKENS_SECT[$match[1]]=$sect
    fi
  done < "$file"
}

_tokens_map
for _tok in ${(k)_TOKENS_MAP}; do
  export "$_tok=$(security find-generic-password -a "$USER" -s "${_TOKENS_MAP[$_tok]}" -w 2>/dev/null)"
done
unset _tok
