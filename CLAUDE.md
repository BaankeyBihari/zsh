# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The single source of truth for the user's zsh environment on macOS (Apple Silicon).
Goal: a fresh machine becomes fully provisioned by running one script, every change is
snapshot-protected, and rollback is always one command away. **All shell config is edited
here and applied via `bin/install.sh` — never edited directly in `$HOME` or `~/.config/zsh/`.**

Stack: plain zsh + **starship** (prompt) + **znap** (plugin manager, loading
zsh-autosuggestions + zsh-syntax-highlighting). No Oh My Zsh. fzf drives Ctrl-R/Ctrl-T/Alt-C
(wired in `config/60-tools.zsh`); modern CLI replacements (eza, bat, ripgrep, fd, delta) are
provisioned via the Brewfile with guarded aliases in `config/70-aliases.zsh`.

## Load model

zsh always reads `~/.zshenv` first. Ours is the only file placed in `$HOME` proper; it sets
`ZDOTDIR=$XDG_CONFIG_HOME/zsh` and runs `brew shellenv`, so every other config file lives
under `~/.config/zsh/`. Source order:

1. `~/.zshenv` (→ `home/zshenv`) — XDG paths, `ZDOTDIR`, Homebrew PATH. Runs for **every** shell.
2. `~/.zprofile` (→ `home/zprofile`) — login shells; intentionally minimal.
3. `$ZDOTDIR/.zshenv` (→ `config/.zshenv`) — the granted `assume` alias; runs for every shell.
4. `$ZDOTDIR/.zshrc` (→ `config/.zshrc`) — interactive driver. It sources the `NN-*.zsh`
   fragments from `$ZDOTDIR/zsh.d/` **in lexical filename order**, then `99-local.zsh` if present.

The fragments (`config/00-env.zsh` … `config/90-prompt.zsh`) own all real config:
env → path → options → znap → plugins → completions → tools → aliases → functions → prompt.
`install.sh` copies them into `~/.config/zsh/zsh.d/`. `99-local.zsh` (gitignored)
sits at the `~/.config/zsh/` root — outside `zsh.d/`, so an install never purges it — and is the
last-loaded, machine-specific override layer. It sources `local-secrets.zsh` (also installed to
the root, but tracked in the repo as `config/local-secrets.zsh`), which holds env vars whose
*values* are derived at shell start (keychain, `docker context inspect`) rather than hardcoded —
safe to commit since no literal secret ever lands in the file.

## How everything maps to the repo

| You want to change…              | Edit…                                  |
| -------------------------------- | -------------------------------------- |
| A new behaviour/setting          | a new `config/NN-name.zsh` fragment    |
| A plugin                         | `config/40-plugins.zsh` (`znap source …`) |
| An alias / function              | `config/70-aliases.zsh` / `80-functions.zsh` |
| The prompt                       | `starship/starship.toml`               |
| A provisioned tool/app           | `Brewfile`                             |
| The `$HOME` stub or `ZDOTDIR`    | `home/zshenv`                          |
| A derived value (keychain, `docker context`) | `config/local-secrets.zsh` (tracked — no literal secrets) |
| A literal secret / hardcoded machine-specific value | `~/.config/zsh/99-local.zsh` (never committed) |

Config is **copied, not symlinked**: `install.sh` copies the driver/stub files into place and
rebuilds `~/.config/zsh/zsh.d/` from scratch each run (deleting a fragment from `config/` drops
it from `zsh.d/` on the next install). `~/.config/zsh/` is always a real directory; `99-local.zsh`
and runtime artifacts live at its root, outside the purged `zsh.d/`. Tradeoff: an edit in this
repo does not take effect until `install.sh` re-runs — `doctor.sh` reports any drift.

## Commands

```sh
bin/install.sh              # apply repo state — snapshot → brew → znap → copy config → doctor. Idempotent.
bin/install.sh --no-brew    # config copy only (skip Homebrew + Brewfile)
bin/update.sh               # upgrade installed packages — snapshot → brew update/upgrade → bundle → uv tool upgrade → cargo tool upgrade → doctor.
bin/update.sh --greedy      # also upgrade self-updating casks; --no-cleanup keeps old versions
bin/snapshot.sh             # manual snapshot before risky edits; prints the timestamp
bin/rollback.sh             # list snapshots
bin/rollback.sh <ts>        # restore a snapshot (or `latest`)
bin/uninstall.sh            # = rollback.sh latest
bin/doctor.sh               # health check: managed-copy drift/stale/missing, tools, znap, startup time. Exit 0 = healthy.
```

Verification helpers:

```sh
zsh -n config/NN-name.zsh           # syntax-check a fragment without sourcing it
time zsh -i -c exit                 # interactive startup time (watch for regressions)
ZDOTDIR=~/.config/zsh zsh -i -c 'alias ll; command -v starship'   # smoke-test a real shell
```

## Working rules for Claude

- **Never edit `$HOME` or `~/.config/zsh/` directly.** They are managed copies, rebuilt from
  the repo. Edit the repo, then run `bin/install.sh` — edits do NOT take effect until it re-runs.
  A hand-edit to an installed copy is drift: `doctor.sh` flags it and the next install clobbers it.
- **`install.sh` snapshots before doing anything.** For edits applied by hand outside the
  installer, run `bin/snapshot.sh` first so rollback stays possible.
- **`install.sh` provisions, `update.sh` upgrades — keep them separate.** `install.sh` only
  installs what's missing (so it stays fast and deterministic); use `bin/update.sh` to pull
  newer versions of brew packages + uv/cargo tools. Caveat: snapshots capture **config only**, so
  `rollback.sh` does NOT undo a package upgrade — recover a bad brew upgrade with brew itself
  (`brew install foo@<version>`), not rollback.
- **Add behaviour as a new `NN-*.zsh` fragment** — do not extend `config/.zshrc`'s loader.
  Pick the prefix by category (see the load-order list above); files load in lexical order, so
  `zsh-syntax-highlighting` must stay last in `40-plugins.zsh`.
- **After any change, run `bin/doctor.sh`** and check `time zsh -i -c exit` hasn't regressed.
- **Smoke-test aliases/functions with representative arguments, not just bare invocations.**
  A bare `tree` passed while `tree bin/` was broken: eza flags with optional values
  (`--icons`, `--classify`) swallow an adjacent path unless pinned with `=auto`. Test each
  new alias/function at least once with a trailing path/argument.
- **Heavy/optional tooling stays lazy or out entirely** so it doesn't tax startup. Prefer
  sourcing static files (fzf keybindings) over `eval "$(tool init)"` subprocesses where an
  option exists.
- **Some tool config lives outside this repo's substrate**: delta is wired as git pager via
  `git config --global` (`~/.gitconfig`) — not snapshot-protected; undo with
  `git config --global --unset`.
- **Docs ship with the change.** If a change alters anything CLAUDE.md or README.md
  describes — commands/flags, fragments, provisioned tools, functions/aliases, invariants,
  the load model — update both files in the same commit. Nothing automated checks docs
  (doctor/pre-commit only verify code), so drift is caught only here.
- The canonical "I broke it" loop: `bin/rollback.sh <prev-ts>` → fix repo → `bin/install.sh`.

## Invariants

- `~/.zshenv` + `~/.zprofile` are the only managed files in `$HOME`; everything else is gated
  through `ZDOTDIR`. Enforced: `install.sh` deletes a legacy `~/.zshrc` (the run's snapshot
  keeps a copy; skipped under `--no-snapshot`), and `doctor.sh` fails while one is present.
- Every managed copy under `~/.config/zsh/` (and the `$HOME`/starship stubs) matches its repo
  source byte-for-byte, and `zsh.d/` holds exactly the current `config/[0-9][0-9]-*.zsh` set.
  `bin/doctor.sh` is authoritative and flags drift, plus any stale (dropped from the repo) or
  missing fragment.
- `snapshots/` is gitignored and is the rollback substrate — it works even if git history is
  unavailable. Each snapshot carries a `manifest.json` (origin paths, sha256, repo HEAD).

## Do not commit

`.zsh_history`, `.zsh_sessions/`, `99-local.zsh` / `*.local.zsh`, any literal secret, and any
hardcoded machine-specific PATH. The `99-local.zsh` escape hatch (see `config/99-local.zsh.example`)
exists precisely so these never enter the repo. `config/local-secrets.zsh` is the one exception:
it's tracked, but only ever holds lookup commands (keychain, `docker context inspect`), never a
literal value — if a var can't be expressed as a derived lookup, it belongs in `99-local.zsh` instead.

## Extras (not repo config)

`extras/claude/GLOBAL_CLAUDE.md` is a backup of the user's machine-global Claude Code rules
(live source `~/.claude/CLAUDE.md`, also a public gist). It is **not** part of this repo's
machinery: not symlinked, not touched by `bin/install.sh`, and may lag the live file. The
global rules still apply via the live file, as in any repo — this copy is just the archive.

## Platform assumptions

macOS + Apple Silicon (`/opt/homebrew`). Python tooling is uv (pyenv and fnm sunset in
2026-09, conda in 2026-07). Porting to Intel/Linux means generalizing the `brew shellenv` paths in
`home/zshenv`.
