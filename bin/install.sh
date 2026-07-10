#!/usr/bin/env bash
# install.sh — apply this repo's shell config to the machine. Idempotent: re-running
# only does work where reality differs from the desired state.
#
# Flow: snapshot → Homebrew → Brewfile → uv tools → znap → copy config → prime → doctor.
#
# Flags:
#   --no-brew          skip Homebrew + Brewfile steps (config copy only)
#   --no-snapshot      skip the safety snapshot (NOT recommended)
#   --skip-prime       don't warm znap plugin clones

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ZDOTDIR_TARGET="$CONFIG_HOME/zsh"

DO_BREW=1; DO_SNAPSHOT=1; DO_PRIME=1
for arg in "$@"; do
  case "$arg" in
    --no-brew)     DO_BREW=0 ;;
    --no-snapshot) DO_SNAPSHOT=0 ;;
    --skip-prime)  DO_PRIME=0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

# --- copy_file: install $1 (repo source) as a plain copy at $2. ---
# Config is copied, not symlinked: a fragment deleted from the repo drops out of the
# installed tree on the next run instead of leaving a dangling link. Tradeoff: editing a
# repo file no longer takes effect until install.sh re-runs. If the destination already
# holds a managed copy whose bytes differ from the repo source, warn before clobbering it
# — the snapshot taken at the top of this run preserves the prior copy.
copy_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    # Legacy symlink (old model) — often points at $src itself, which would make `cp` abort
    # with "are identical". Drop it so we always write a real, independent copy.
    rm -f "$dst"
  elif [[ -f "$dst" && "$(sha "$dst")" != "$(sha "$src")" ]]; then
    warn "overwriting local changes in ${dst/#$HOME/~} (snapshot holds the prior copy)"
  fi
  cp -f "$src" "$dst"
  log "copied ${dst/#$HOME/~}"
}

# --- safe_rmrf: guarded `rm -rf`. ---
# Both this installer and rollback.sh rm -rf a path derived from variables; a bad expansion
# must never be able to wipe $HOME or /. Refuse anything that isn't a real (non-symlink)
# directory living under ~/.config. A path that simply doesn't exist is a no-op success
# (fresh install: there is no zsh.d/ to purge yet).
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

# --- 1. snapshot ---
if [[ $DO_SNAPSHOT -eq 1 ]]; then
  log "Snapshotting current config…"
  TS="$(bash "$REPO/bin/snapshot.sh")"
  log "Snapshot saved: snapshots/$TS"
fi

# --- 2. Homebrew ---
if [[ $DO_BREW -eq 1 ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  # --- 3. Brewfile ---
  log "Applying Brewfile…"
  brew bundle --file="$REPO/Brewfile"

  # --- 3b. uv tools ---
  # Python CLIs with no Homebrew formula, installed via uv (provisioned above).
  # gita: manage many git repos at once.
  # nox: task automation / test matrices across Python versions.
  # virtualenv: standalone venv creator. `uv tool install` is idempotent.
  if command -v uv >/dev/null 2>&1; then
    for tool in gita nox virtualenv; do
      if command -v "$tool" >/dev/null 2>&1; then
        log "uv tool present: $tool"
      else
        log "Installing uv tool: $tool"
        uv tool install "$tool"
      fi
    done
  fi
else
  warn "Skipping Homebrew/Brewfile (--no-brew)"
fi

# --- 4. znap ---
if [[ ! -r "$DATA_HOME/znap/znap.zsh" ]]; then
  log "Cloning znap…"
  mkdir -p "$DATA_HOME"
  git clone --depth=1 https://github.com/marlonrichert/zsh-snap.git "$DATA_HOME/znap"
else
  log "znap present."
fi

# --- 5. copy config into place ---
# Everything managed is a plain copy. Order matters: copy the self-contained driver/stub
# files first, then do the one destructive step — purging and rebuilding zsh.d/ — LAST,
# and atomically (build into zsh.d.tmp, then swap), so a mid-run failure never leaves a
# half-populated fragment directory that a shell might source.
log "Copying config into place…"
mkdir -p "$CONFIG_HOME"

# ~/.config/zsh must be a REAL directory, never a symlink. Adopt a machine migrating from
# the old folder-symlink model by replacing the link with a real dir.
if [[ -L "$ZDOTDIR_TARGET" ]]; then
  rm "$ZDOTDIR_TARGET"
  log "removed legacy folder symlink ~/.config/zsh"
fi
mkdir -p "$ZDOTDIR_TARGET"

# Purge legacy per-file symlinks left at the ZDOTDIR root by the old model (fragments plus
# the .zshrc/.zshenv driver links). Only symlinks are removed — real files (99-local.zsh,
# runtime .zcompdump*/.zwc, .zsh_sessions/) are left untouched.
for p in "$ZDOTDIR_TARGET"/*.zsh "$ZDOTDIR_TARGET/.zshrc" "$ZDOTDIR_TARGET/.zshenv"; do
  if [[ -L "$p" ]]; then
    rm "$p"
    log "removed legacy symlink ${p/#$HOME/~}"
  fi
done

# $HOME stubs + driver files + starship (all self-contained copies).
copy_file "$REPO/home/zshenv"          "$HOME/.zshenv"
copy_file "$REPO/home/zprofile"        "$HOME/.zprofile"
copy_file "$REPO/config/.zshrc"        "$ZDOTDIR_TARGET/.zshrc"
copy_file "$REPO/config/.zshenv"       "$ZDOTDIR_TARGET/.zshenv"
copy_file "$REPO/starship/starship.toml" "$CONFIG_HOME/starship.toml"

# Rebuild zsh.d/ from scratch (pack and replace): a fragment deleted from config/ drops
# out here on the next run. The glob matches only NN-*.zsh fragments, so .zshrc, .zshenv
# and 99-local.zsh.example are excluded. 99-local.zsh lives at the ZDOTDIR root, never here.
# Build into a temp dir first, then swap, so a mid-run failure never leaves zsh.d/ partial.
ZSHD="$ZDOTDIR_TARGET/zsh.d"
ZSHD_TMP="$ZDOTDIR_TARGET/zsh.d.tmp"
safe_rmrf "$ZSHD_TMP"
mkdir -p "$ZSHD_TMP"
for src in "$REPO"/config/[0-9][0-9]-*.zsh; do
  base="$(basename "$src")"
  # Warn if the currently-installed copy was changed out from under the repo (pitfall #1).
  if [[ -f "$ZSHD/$base" && "$(sha "$ZSHD/$base")" != "$(sha "$src")" ]]; then
    warn "overwriting local changes in ${ZSHD/#$HOME/~}/$base (snapshot holds the prior copy)"
  fi
  cp -f "$src" "$ZSHD_TMP/$base"
done
safe_rmrf "$ZSHD"
mv "$ZSHD_TMP" "$ZSHD"
log "rebuilt ~/.config/zsh/zsh.d (fragments copied)"

# --- 6. prime plugins ---
# Only when we have a TTY: priming spawns an interactive shell that sources
# 40-plugins.zsh, which makes znap clone plugin repos. GIT_TERMINAL_PROMPT=0 guarantees
# git fails fast instead of blocking on a credential prompt in a headless/CI run.
if [[ $DO_PRIME -eq 1 && -t 0 ]]; then
  log "Priming znap plugin clones (first run may take a moment)…"
  GIT_TERMINAL_PROMPT=0 ZDOTDIR="$ZDOTDIR_TARGET" zsh -i -c 'exit' \
    || warn "Plugin priming returned non-zero; check a fresh shell."
elif [[ $DO_PRIME -eq 1 ]]; then
  warn "No TTY; skipping plugin priming. First interactive shell will clone plugins."
fi

# --- 7. verify ---
log "Running doctor…"
bash "$REPO/bin/doctor.sh" || warn "doctor reported issues (see above)."

log "Done. Open a new terminal, or run: exec zsh"
