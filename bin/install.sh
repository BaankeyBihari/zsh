#!/usr/bin/env bash
# install.sh — apply this repo's shell config to the machine. Idempotent: re-running
# only does work where reality differs from the desired state.
#
# Flow: snapshot → Homebrew → Brewfile → uv tools → znap → symlinks → prime → doctor.
#
# Flags:
#   --no-brew          skip Homebrew + Brewfile steps (config/symlinks only)
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

# --- link helper: write symlink at $2 -> $1. ---
# A real (non-symlink) file at the target is adopted ONLY when this run took a snapshot,
# so the original is recoverable via rollback. Without a snapshot (--no-snapshot) we
# refuse, to avoid destroying an unmanaged file with no backup.
link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      return 0   # already correct
    fi
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    if [[ $DO_SNAPSHOT -eq 1 ]]; then
      rm -f "$dst"
      log "adopted ${dst/#$HOME/~} (original preserved in this run's snapshot)"
    else
      warn "refusing to overwrite non-symlink without a snapshot: $dst (re-run without --no-snapshot, or remove it manually)"
      return 0
    fi
  fi
  ln -s "$src" "$dst"
  log "linked ${dst/#$HOME/~} -> ${src/#$HOME/~}"
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

# --- 5. symlinks ---
log "Linking config…"
mkdir -p "$ZDOTDIR_TARGET"

# $HOME/.zshenv -> repo/home/zshenv ; $HOME/.zprofile -> repo/home/zprofile
link "$REPO/home/zshenv"   "$HOME/.zshenv"
link "$REPO/home/zprofile" "$HOME/.zprofile"

# Every tracked file in config/ (dotfiles + NN-*.zsh, excluding the .example template)
# -> ~/.config/zsh/<name>
shopt -s dotglob nullglob
for f in "$REPO/config/"*; do
  base="$(basename "$f")"
  [[ "$base" == "99-local.zsh.example" ]] && continue
  link "$f" "$ZDOTDIR_TARGET/$base"
done
shopt -u dotglob nullglob

# starship config
link "$REPO/starship/starship.toml" "$CONFIG_HOME/starship.toml"

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
