# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The single source of truth for the user's zsh environment on macOS (Apple Silicon).
Goal: a fresh machine becomes fully provisioned by running one script, every change is
snapshot-protected, and rollback is always one command away. **All shell config is edited
here and applied via `bin/install.sh` — never edited directly in `$HOME` or `~/.config/zsh/`.**

Stack: plain zsh + **starship** (prompt) + **znap** (plugin manager). No Oh My Zsh.

## Load model

zsh always reads `~/.zshenv` first. Ours is the only file placed in `$HOME` proper; it sets
`ZDOTDIR=$XDG_CONFIG_HOME/zsh` and runs `brew shellenv`, so every other config file lives
under `~/.config/zsh/`. Source order:

1. `~/.zshenv` (→ `home/zshenv`) — XDG paths, `ZDOTDIR`, Homebrew PATH. Runs for **every** shell.
2. `~/.zprofile` (→ `home/zprofile`) — login shells; intentionally minimal.
3. `$ZDOTDIR/.zshenv` (→ `config/.zshenv`) — the granted `assume` alias; runs for every shell.
4. `$ZDOTDIR/.zshrc` (→ `config/.zshrc`) — interactive driver. It just sources `NN-*.zsh`
   fragments **in lexical filename order**, then `99-local.zsh` if present.

The fragments (`config/00-env.zsh` … `config/95-integrations.zsh`) own all real config:
env → path → options → znap → plugins → completions → tools → aliases → functions → prompt →
integrations. `99-local.zsh` (gitignored) is the last-loaded, machine-specific override layer.

## How everything maps to the repo

| You want to change…              | Edit…                                  |
| -------------------------------- | -------------------------------------- |
| A new behaviour/setting          | a new `config/NN-name.zsh` fragment    |
| A plugin                         | `config/40-plugins.zsh` (`znap source …`) |
| An alias / function              | `config/70-aliases.zsh` / `80-functions.zsh` |
| The prompt                       | `starship/starship.toml`               |
| A provisioned tool/app           | `Brewfile`                             |
| The `$HOME` stub or `ZDOTDIR`    | `home/zshenv`                          |
| Machine-specific / secret value  | `~/.config/zsh/99-local.zsh` (never committed) |

Symlinks are per-file: `~/.config/zsh/` is a real directory of symlinks into `config/`, which
is what lets `99-local.zsh` coexist with managed files.

## Commands

```sh
bin/install.sh              # apply repo state — snapshot → brew → znap → symlinks → doctor. Idempotent.
bin/install.sh --no-brew    # config/symlinks only (skip Homebrew + Brewfile)
bin/snapshot.sh             # manual snapshot before risky edits; prints the timestamp
bin/rollback.sh             # list snapshots
bin/rollback.sh <ts>        # restore a snapshot (or `latest`)
bin/uninstall.sh            # = rollback.sh latest
bin/doctor.sh               # health check: symlinks, tools, znap, startup time. Exit 0 = healthy.
```

Verification helpers:

```sh
zsh -n config/NN-name.zsh           # syntax-check a fragment without sourcing it
time zsh -i -c exit                 # interactive startup time (watch for regressions)
ZDOTDIR=~/.config/zsh zsh -i -c 'alias ll; command -v starship'   # smoke-test a real shell
```

## Working rules for Claude

- **Never edit `$HOME` or `~/.config/zsh/` directly.** They are symlinks/managed output.
  Edit the repo, then run `bin/install.sh`.
- **`install.sh` snapshots before doing anything.** For edits applied by hand outside the
  installer, run `bin/snapshot.sh` first so rollback stays possible.
- **Add behaviour as a new `NN-*.zsh` fragment** — do not extend `config/.zshrc`'s loader.
  Pick the prefix by category (see the load-order list above); files load in lexical order, so
  `zsh-syntax-highlighting` must stay last in `40-plugins.zsh`.
- **After any change, run `bin/doctor.sh`** and check `time zsh -i -c exit` hasn't regressed.
- **Heavy/optional tooling stays lazy** (e.g. conda via `loadconda`) so it doesn't tax startup.
- The canonical "I broke it" loop: `bin/rollback.sh <prev-ts>` → fix repo → `bin/install.sh`.

## Invariants

- `~/.zshenv` + `~/.zprofile` are the only managed files in `$HOME`; everything else is gated
  through `ZDOTDIR`.
- Every managed symlink resolves into this repo. `bin/doctor.sh` is authoritative and flags
  any symlink that points elsewhere or any unmanaged file in `~/.config/zsh/`.
- `snapshots/` is gitignored and is the rollback substrate — it works even if git history is
  unavailable. Each snapshot carries a `manifest.json` (origin paths, sha256, repo HEAD).

## Do not commit

`.zsh_history`, `.zsh_sessions/`, `99-local.zsh` / `*.local.zsh`, anything secret, and any
machine-specific PATH. The `99-local.zsh` escape hatch (see `config/99-local.zsh.example`)
exists precisely so these never enter the repo.

## Platform assumptions

macOS + Apple Silicon (`/opt/homebrew`). conda defaults to `miniconda` via the Brewfile.
Porting to Intel/Linux means generalizing the `brew shellenv` paths in `home/zshenv` and the
conda search paths in `config/80-functions.zsh`.
