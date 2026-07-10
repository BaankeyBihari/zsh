#!/usr/bin/env bash
# snapshot.sh — capture the current on-disk shell config into snapshots/<timestamp>/.
# Called automatically by install.sh; also runnable standalone before risky edits.
#
# Captures: ~/.zshenv ~/.zshrc ~/.zprofile ~/.config/zsh/ ~/.config/starship.toml
# Writes:   snapshots/<ts>/{home/,config-zsh/,starship.toml,manifest.json}
#
# Prints the snapshot timestamp on stdout (so callers can capture it).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP_ROOT="$REPO/snapshots"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$SNAP_ROOT/$TS"

mkdir -p "$DEST/home" "$DEST/config-zsh"

sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

manifest_entries=()

capture_file() {
  # $1 = source path, $2 = dest path, $3 = logical name for manifest
  local src="$1" dst="$2" name="$3"
  if [[ -e "$src" || -L "$src" ]]; then
    # -RP: copy managed files as-is and preserve any legacy symlink as a symlink, so a
    # snapshot records exactly what was on disk (post-migration these are plain copies).
    cp -RP "$src" "$dst"
    local checksum=""
    [[ -f "$src" && ! -L "$src" ]] && checksum="$(sha "$src")"
    manifest_entries+=("$(printf '{"name":"%s","origin":"%s","stored":"%s","is_symlink":%s,"symlink_target":"%s","sha256":"%s"}' \
      "$name" "$src" "${dst#$DEST/}" \
      "$([[ -L "$src" ]] && echo true || echo false)" \
      "$([[ -L "$src" ]] && readlink "$src" || echo "")" \
      "$checksum")")
  fi
}

capture_file "$HOME/.zshenv"   "$DEST/home/.zshenv"   "home/.zshenv"
capture_file "$HOME/.zshrc"    "$DEST/home/.zshrc"    "home/.zshrc"
capture_file "$HOME/.zprofile" "$DEST/home/.zprofile" "home/.zprofile"
capture_file "$HOME/.config/starship.toml" "$DEST/starship.toml" "config/starship.toml"

# Capture the whole ~/.config/zsh tree (files + symlinks) if it exists.
if [[ -d "$HOME/.config/zsh" ]]; then
  cp -RP "$HOME/.config/zsh/." "$DEST/config-zsh/"
fi

repo_head="$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo "no-git")"

{
  printf '{\n'
  printf '  "timestamp": "%s",\n' "$TS"
  printf '  "repo_head": "%s",\n' "$repo_head"
  printf '  "host": "%s",\n' "$(hostname)"
  printf '  "entries": [\n'
  local_first=1
  for e in "${manifest_entries[@]:-}"; do
    [[ -z "$e" ]] && continue
    if [[ $local_first -eq 1 ]]; then local_first=0; else printf ',\n'; fi
    printf '    %s' "$e"
  done
  printf '\n  ]\n'
  printf '}\n'
} > "$DEST/manifest.json"

echo "$TS"
