#!/usr/bin/env bash
# rollback.sh — restore a snapshot, undoing what install.sh did.
#
# Usage:
#   bin/rollback.sh                 # list available snapshots
#   bin/rollback.sh <timestamp>     # restore that snapshot
#   bin/rollback.sh latest          # restore the most recent snapshot
#
# Restore procedure:
#   1. Remove repo-managed paths (whether copies or legacy symlinks) at ~/.zshenv,
#      ~/.zprofile, ~/.config/starship.toml, and the whole ~/.config/zsh/ tree.
#   2. Copy the captured originals back to their origin paths from the snapshot.
#   3. Syntax-check restored zsh files with `zsh -n`.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP_ROOT="$REPO/snapshots"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ZDOTDIR_TARGET="$CONFIG_HOME/zsh"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# Guarded `rm -rf` (mirrors install.sh): refuse anything that isn't a real (non-symlink)
# directory under ~/.config. A path that doesn't exist is a no-op success.
safe_rmrf() {
  local p="$1"
  [[ -e "$p" || -L "$p" ]] || return 0
  if [[ -n "$p" && "$p" == "$CONFIG_HOME/"* && -d "$p" && ! -L "$p" ]]; then
    rm -rf "$p"
    return 0
  fi
  warn "safe_rmrf refused unsafe target: $p"
  return 1
}

list_snapshots() {
  if [[ -d "$SNAP_ROOT" ]] && compgen -G "$SNAP_ROOT/*/manifest.json" >/dev/null; then
    log "Available snapshots:"
    for d in "$SNAP_ROOT"/*/; do
      [[ -f "$d/manifest.json" ]] || continue
      printf '  %s\n' "$(basename "$d")"
    done
  else
    warn "No snapshots found in $SNAP_ROOT"
  fi
}

TS="${1:-}"
if [[ -z "$TS" ]]; then
  list_snapshots
  echo
  echo "Run: bin/rollback.sh <timestamp>   (or 'latest')"
  exit 0
fi

if [[ "$TS" == "latest" ]]; then
  TS="$(ls -1 "$SNAP_ROOT" 2>/dev/null | sort | tail -n1 || true)"
  [[ -z "$TS" ]] && { warn "No snapshots to restore."; exit 1; }
  log "Latest snapshot: $TS"
fi

SNAP="$SNAP_ROOT/$TS"
[[ -f "$SNAP/manifest.json" ]] || { warn "No snapshot at $SNAP"; list_snapshots; exit 1; }

# --- 1. remove managed paths ---
# Managed config is now plain copies (older machines may still have symlinks). Remove the
# stub/starship paths whether copy or symlink; the snapshot holds the true original and
# step 2 restores it. The whole ~/.config/zsh tree is purged in step 2, just before its
# contents are restored, so no leftover zsh.d/ fragment survives a rollback.
remove_managed() {
  local p="$1"
  if [[ -L "$p" ]]; then
    rm "$p"
    log "removed link ${p/#$HOME/~} (was -> $(readlink "$p" 2>/dev/null))"
  elif [[ -e "$p" ]]; then
    rm -f "$p"
    log "removed ${p/#$HOME/~}"
  fi
}

remove_managed "$HOME/.zshenv"
remove_managed "$HOME/.zprofile"
remove_managed "$CONFIG_HOME/starship.toml"

# --- 2. restore captured originals ---
restore() {
  # $1 = path inside snapshot, $2 = destination
  local stored="$SNAP/$1" dest="$2"
  [[ -e "$stored" || -L "$stored" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  cp -RP "$stored" "$dest"
  log "restored ${dest/#$HOME/~}"
}

restore "home/.zshenv"   "$HOME/.zshenv"
restore "home/.zshrc"    "$HOME/.zshrc"
restore "home/.zprofile" "$HOME/.zprofile"
restore "starship.toml"  "$CONFIG_HOME/starship.toml"

if [[ -d "$SNAP/config-zsh" ]] && compgen -G "$SNAP/config-zsh/*" >/dev/null; then
  # Purge the current tree first so the restore is exact — no stale zsh.d/ fragments or
  # driver files linger. The snapshot captured the full tree (incl. 99-local.zsh and
  # runtime artifacts), so nothing unique is lost.
  safe_rmrf "$ZDOTDIR_TARGET"
  mkdir -p "$ZDOTDIR_TARGET"
  cp -RP "$SNAP/config-zsh/." "$ZDOTDIR_TARGET/"
  log "restored ~/.config/zsh contents"
fi

# --- 3. syntax-check restored zsh files ---
for f in "$HOME/.zshenv" "$HOME/.zshrc"; do
  [[ -f "$f" ]] || continue
  if zsh -n "$f" 2>/dev/null; then
    log "syntax OK: ${f/#$HOME/~}"
  else
    warn "syntax check FAILED: ${f/#$HOME/~}"
  fi
done

log "Rollback to $TS complete. Open a new terminal, or run: exec zsh"
