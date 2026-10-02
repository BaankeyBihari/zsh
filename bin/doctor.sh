#!/usr/bin/env bash
# doctor.sh — health check. Verifies the managed config copies match the repo (no drift,
# no stale/missing fragments), required tools exist, znap is present, and reports
# interactive startup time. Exit 0 = healthy.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ZDOTDIR_TARGET="$CONFIG_HOME/zsh"
GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"

PASS=0
FAIL=0
ok() {
  printf '  \033[1;32m✓\033[0m %s\n' "$*"
  PASS=$((PASS + 1))
}
bad() {
  printf '  \033[1;31m✗\033[0m %s\n' "$*"
  FAIL=$((FAIL + 1))
}
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

check_copy "$REPO/home/zshenv" "$HOME/.zshenv"
check_copy "$REPO/home/zprofile" "$HOME/.zprofile"
check_copy "$REPO/starship/starship.toml" "$CONFIG_HOME/starship.toml"
check_copy "$REPO/tmux/tmux.conf" "$CONFIG_HOME/tmux/tmux.conf"
check_copy "$REPO/ghostty/config.ghostty" "$GHOSTTY_DIR/config.ghostty"
check_copy "$REPO/config/.zshrc" "$ZDOTDIR_TARGET/.zshrc"
check_copy "$REPO/config/.zshenv" "$ZDOTDIR_TARGET/.zshenv"
check_copy "$REPO/config/local-exports.zsh" "$ZDOTDIR_TARGET/local-exports.zsh"
check_copy "$REPO/mani/tasks.yaml" "$CONFIG_HOME/mani/tasks.yaml"

# Token map: only the managed section (above `unmanaged:`) must match the repo; the
# unmanaged section is user-owned and never flagged. Each mapped service must exist in the keychain.
TOKEN_MAP="$CONFIG_HOME/tokens/map.yaml"
if [[ ! -f "$TOKEN_MAP" ]]; then
  bad "${TOKEN_MAP/#$HOME/~} missing — re-run install.sh"
else
  if [[ "$(sed '/^unmanaged:/,$d' "$TOKEN_MAP" | shasum -a 256)" == "$(shasum -a 256 <"$REPO/config/tokens-map.yaml")" ]]; then
    ok "${TOKEN_MAP/#$HOME/~} managed section matches repo"
  else
    bad "${TOKEN_MAP/#$HOME/~} managed section drift — re-run install.sh"
  fi
  while IFS=' ' read -r name svc; do
    if security find-generic-password -a "$USER" -s "$svc" >/dev/null 2>&1; then
      ok "keychain has $svc ($name)"
    else
      info "keychain missing $svc ($name) — tokens set $name"
    fi
  done < <(sed -nE 's/^[[:space:]]+([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*([^[:space:]#]+).*/\1 \2/p' "$TOKEN_MAP")
fi

# $HOME must hold no zsh config beyond the managed stubs. A leftover pre-migration
# ~/.zshrc is ignored while ZDOTDIR is set, but would take effect if ~/.zshenv were lost.
if [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; then
  bad "~/.zshrc present (legacy, unmanaged) — re-run install.sh to remove it"
else
  ok "no stray ~/.zshrc in \$HOME"
fi

# zsh.d/ fragments: the set of NN-*.zsh basenames must match config/ exactly, and each
# common fragment must be an untouched copy. Flags missing (in repo, absent from zsh.d/)
# and stale (in zsh.d/, dropped from repo) fragments.
ZSHD="$ZDOTDIR_TARGET/zsh.d"
if [[ ! -d "$ZSHD" ]]; then
  bad "${ZSHD/#$HOME/~} missing — re-run install.sh"
else
  for src in "$REPO"/config/[0-9][0-9]-*.zsh; do
    [[ -e "$src" ]] || continue # no fragments in repo (shouldn't happen)
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
    [[ -e "$dst" ]] || continue # empty zsh.d/
    base="$(basename "$dst")"
    [[ -e "$REPO/config/$base" ]] || bad "zsh.d/$base stale (not in repo) — re-run install.sh"
  done
fi

# --- tools ---
head "Tools"
for t in zsh git starship uv; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t: $(command -v "$t")"; else bad "$t not found"; fi
done

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
