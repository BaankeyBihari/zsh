#!/usr/bin/env bash
# doctor.sh — health check. Verifies the managed config copies match the repo (no drift,
# no stale/missing fragments), required tools exist, znap is present, and reports
# interactive startup time. Exit 0 = healthy.

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

# --- managed config is a faithful copy of the repo ---
head "Managed config"
sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

# Each managed copy must exist and match its repo source byte-for-byte. Drift means the
# installed file was hand-edited (or the repo changed without a re-install).
check_copy() {
  local src="$1" dst="$2"
  if [[ ! -e "$dst" ]]; then
    bad "${dst/#$HOME/~} missing — re-run install.sh"
  elif [[ -L "$dst" ]]; then
    bad "${dst/#$HOME/~} is a symlink (legacy) — re-run install.sh"
  elif [[ "$(sha "$dst")" == "$(sha "$src")" ]]; then
    ok "${dst/#$HOME/~} matches repo"
  else
    bad "${dst/#$HOME/~} drift — re-run install.sh"
  fi
}

# ~/.config/zsh must be a real directory, never a symlink.
if [[ -L "$ZDOTDIR_TARGET" ]]; then
  bad "${ZDOTDIR_TARGET/#$HOME/~} is a symlink (legacy) — re-run install.sh"
elif [[ ! -d "$ZDOTDIR_TARGET" ]]; then
  bad "${ZDOTDIR_TARGET/#$HOME/~} missing — re-run install.sh"
else
  ok "${ZDOTDIR_TARGET/#$HOME/~} is a real directory"
fi

check_copy "$REPO/home/zshenv"            "$HOME/.zshenv"
check_copy "$REPO/home/zprofile"          "$HOME/.zprofile"
check_copy "$REPO/starship/starship.toml" "$CONFIG_HOME/starship.toml"
check_copy "$REPO/config/.zshrc"          "$ZDOTDIR_TARGET/.zshrc"
check_copy "$REPO/config/.zshenv"         "$ZDOTDIR_TARGET/.zshenv"

# zsh.d/ fragments: the set of NN-*.zsh basenames must match config/ exactly, and each
# common fragment must be an untouched copy. Flags missing (in repo, absent from zsh.d/)
# and stale (in zsh.d/, dropped from repo) fragments.
ZSHD="$ZDOTDIR_TARGET/zsh.d"
if [[ ! -d "$ZSHD" ]]; then
  bad "${ZSHD/#$HOME/~} missing — re-run install.sh"
else
  for src in "$REPO"/config/[0-9][0-9]-*.zsh; do
    [[ -e "$src" ]] || continue          # no fragments in repo (shouldn't happen)
    base="$(basename "$src")"
    dst="$ZSHD/$base"
    if [[ ! -e "$dst" ]]; then
      bad "zsh.d/$base missing — re-run install.sh"
    elif [[ "$(sha "$dst")" == "$(sha "$src")" ]]; then
      ok "zsh.d/$base matches repo"
    else
      bad "zsh.d/$base drift — re-run install.sh"
    fi
  done
  for dst in "$ZSHD"/[0-9][0-9]-*.zsh; do
    [[ -e "$dst" ]] || continue          # empty zsh.d/
    base="$(basename "$dst")"
    [[ -e "$REPO/config/$base" ]] || bad "zsh.d/$base stale (not in repo) — re-run install.sh"
  done
fi

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
