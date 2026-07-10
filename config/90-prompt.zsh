# starship: TOML-configured prompt at ~/.config/starship.toml (copied from
# ~/zsh/starship/starship.toml by install.sh). Fallback to %~ %# if starship isn't installed yet.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  PROMPT='%F{cyan}%~%f %# '
fi
