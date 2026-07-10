#!/usr/bin/env bash
# update.sh — freshen what's already installed: Homebrew packages and uv tools.
#
# Distinct from install.sh on purpose: install PROVISIONS (bring the machine up to match
# the repo — installs what's missing, never upgrades). update UPGRADES (pull newer
# versions of what's already there). Keeping them separate is what lets a quick config
# apply (install.sh) stay fast and deterministic while upgrades remain an explicit choice.
#
# IMPORTANT: package upgrades are NOT covered by the snapshot/rollback substrate.
# bin/snapshot.sh captures shell *config* only (dotfiles + managed copies), not brew/uv package
# state. If a brew upgrade breaks something, recover with brew itself (reinstall a pinned
# version, e.g. `brew install foo@1.2`), NOT bin/rollback.sh. The snapshot taken here
# protects your config during the run; it does not roll packages back.
#
# Flow: snapshot → brew update → brew upgrade → brew bundle → uv tool upgrade → doctor.
#
# Flags:
#   --no-snapshot   skip the config safety snapshot (NOT recommended)
#   --greedy        also upgrade casks that manage their own auto-updates
#   --no-cleanup    skip `brew cleanup` (keep old downloads/versions)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DO_SNAPSHOT=1; GREEDY=0; DO_CLEANUP=1
for arg in "$@"; do
  case "$arg" in
    --no-snapshot) DO_SNAPSHOT=0 ;;
    --greedy)      GREEDY=1 ;;
    --no-cleanup)  DO_CLEANUP=0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# --- 1. snapshot (config only — see header note) ---
if [[ $DO_SNAPSHOT -eq 1 ]]; then
  log "Snapshotting current config…"
  TS="$(bash "$REPO/bin/snapshot.sh")"
  log "Snapshot saved: snapshots/$TS  (config only — does NOT cover package upgrades)"
fi

# --- 2. Homebrew ---
# Each brew step is best-effort: one failing cask shouldn't abort the rest of the run,
# so failures warn and continue rather than tripping `set -e`.
if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew ]]; then
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

  log "Updating Homebrew package index…"
  brew update || warn "brew update failed; continuing with the cached index."

  log "Upgrading Homebrew packages…"
  if [[ $GREEDY -eq 1 ]]; then
    brew upgrade --greedy || warn "some brew upgrades failed (see above)."
  else
    brew upgrade || warn "some brew upgrades failed (see above)."
  fi

  # Reconcile the Brewfile so anything added to it since the last install lands too.
  log "Reconciling Brewfile…"
  brew bundle --file="$REPO/Brewfile" || warn "brew bundle reported issues."

  if [[ $DO_CLEANUP -eq 1 ]]; then
    log "Cleaning up old Homebrew versions…"
    brew cleanup || warn "brew cleanup reported issues."
  fi
else
  warn "Homebrew not found; skipping brew steps."
fi

# --- 3. uv tools ---
if command -v uv >/dev/null 2>&1; then
  log "Upgrading uv tools…"
  uv tool upgrade --all || warn "uv tool upgrade reported issues."
else
  warn "uv not found; skipping uv tool upgrades."
fi

# --- 4. verify ---
log "Running doctor…"
bash "$REPO/bin/doctor.sh" || warn "doctor reported issues (see above)."

log "Done. Open a new terminal, or run: exec zsh"
