#!/usr/bin/env bash
# doctor.sh — health check. Verifies symlinks point into this repo, required tools
# exist, znap is present, and reports interactive startup time. Exit 0 = healthy.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ZDOTDIR_TARGET="$CONFIG_HOME/zsh"

PASS=0; FAIL=0
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
info() { printf '  \033[1;34mi\033[0m %s\n' "$*"; }
head() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# --- symlinks resolve into the repo ---
head "Symlinks"
check_link() {
  local p="$1" tgt
  tgt="$(readlink "$p" 2>/dev/null || true)"
  if [[ -L "$p" && "$tgt" == "$REPO/"* ]]; then
    ok "${p/#$HOME/~} -> repo${tgt#$REPO}"
  elif [[ -L "$p" ]]; then
    bad "${p/#$HOME/~} is a symlink but NOT into this repo ($(readlink "$p"))"
  elif [[ -e "$p" ]]; then
    bad "${p/#$HOME/~} exists but is not a symlink (unmanaged)"
  else
    bad "${p/#$HOME/~} missing"
  fi
}
check_link "$HOME/.zshenv"
check_link "$HOME/.zprofile"
check_link "$ZDOTDIR_TARGET/.zshrc"
check_link "$ZDOTDIR_TARGET/.zshenv"
check_link "$CONFIG_HOME/starship.toml"
for f in "$REPO/config/"[0-9][0-9]-*.zsh; do
  check_link "$ZDOTDIR_TARGET/$(basename "$f")"
done

# --- stray files in ~/.config/zsh not managed by the repo ---
head "Stray files in ~/.config/zsh"
stray=0
if [[ -d "$ZDOTDIR_TARGET" ]]; then
  shopt -s dotglob nullglob
  for p in "$ZDOTDIR_TARGET"/*; do
    base="$(basename "$p")"
    case "$base" in
      99-local.zsh|.zcompdump*|.zsh_history|history) continue ;;  # expected local artifacts
    esac
    if [[ ! -L "$p" ]]; then
      info "unmanaged: $base (fine if intentional; not from repo)"
      stray=$((stray+1))
    fi
  done
  shopt -u dotglob nullglob
fi
[[ $stray -eq 0 ]] && ok "no unexpected stray files"

# --- tools ---
head "Tools"
for t in zsh git starship fnm pyenv; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t: $(command -v "$t")"; else bad "$t not found"; fi
done
if [[ -d /opt/homebrew/Caskroom/miniconda || -d /opt/homebrew/anaconda3 ]]; then
  ok "conda distribution present (use 'loadconda')"
else
  bad "no conda distribution found"
fi

# --- znap ---
head "znap"
if [[ -r "$DATA_HOME/znap/znap.zsh" ]]; then ok "znap at $DATA_HOME/znap"; else bad "znap not cloned"; fi

# --- startup time ---
head "Startup time"
if command -v zsh >/dev/null 2>&1; then
  # Measure inside zsh with microsecond EPOCHREALTIME (no python3 dependency, no 1s
  # rounding). Average of 3 interactive startups.
  avg=$(zsh -fc '
    zmodload zsh/datetime
    total=0
    for _ in 1 2 3; do
      s=$EPOCHREALTIME
      zsh -i -c exit >/dev/null 2>&1
      e=$EPOCHREALTIME
      total=$(( total + (e - s) ))
    done
    printf "%.3f" $(( total / 3 ))
  ')
  info "avg interactive startup: ${avg}s (3 runs)"
  awk "BEGIN{exit !($avg < 1.0)}" && ok "under 1.0s threshold" || bad "over 1.0s — investigate slow fragments"
fi

head "Summary"
printf '  %d passed, %d failed\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
