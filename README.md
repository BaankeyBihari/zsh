# zsh

My zsh environment, version-controlled. One repo, one install command, snapshot-based rollback.

Stack: **plain zsh + [starship](https://starship.rs) + [znap](https://github.com/marlonrichert/zsh-snap)**. macOS / Apple Silicon.

## Install (fresh machine)

```sh
git clone <this-repo> ~/zsh && ~/zsh/bin/install.sh
exec zsh
```

`install.sh` snapshots the current config, installs Homebrew + everything in the `Brewfile`
(zsh, git, starship, fzf, ripgrep, eza, bat, fd, delta, hyperfine, Ghostty,
…), clones znap, copies the config into place (removing any stray pre-migration `~/.zshrc` —
the snapshot keeps a copy), then runs `doctor.sh`. It's
idempotent — safe to re-run any time. Config is **copied**, not symlinked, so edits in this
repo only take effect after you re-run `install.sh`.

## Layout

```
home/      → ~/.zshenv, ~/.zprofile        (the only files placed in $HOME)
config/    → ~/.config/zsh/                 (.zshrc + .zshenv drivers and local-secrets.zsh
             copied to the root; NN-*.zsh fragments copied into ~/.config/zsh/zsh.d/)
starship/  → ~/.config/starship.toml
tmux/      → ~/.config/tmux/tmux.conf      (status bar + mouse/focus/clipboard + split binds; per-agent logo from session-name prefix)
ghostty/   → ~/Library/Application Support/com.mitchellh.ghostty/config.ghostty
             (font, tabs, quick terminal; cmd+d/cmd+shift+e/f/cmd+alt+arrows send tmux split binds)
mani/      → ~/.config/mani/tasks.yaml     (global sync/create-work tasks, imported by
             each project's own mani.yaml)
Brewfile     provisioned tools/apps
bin/         install · update · snapshot · rollback · uninstall · doctor
snapshots/   timestamped backups (gitignored)
```

Everything under `~/.config/zsh/` is a plain copy of this repo. `install.sh` rebuilds
`~/.config/zsh/zsh.d/` from scratch every run ("pack and replace"), so a fragment you delete
from `config/` drops out on the next install — no dangling files left behind. Only
`99-local.zsh` and runtime artifacts survive at the `~/.config/zsh/` root.

`~/.zshenv` points zsh at `~/.config/zsh/`; `.zshrc` sources the `zsh.d/NN-*.zsh` fragments in
order, then `99-local.zsh`. To add config, drop a new numbered fragment in `config/` and re-run
`install.sh` — don't edit `.zshrc`.

## What the shell gives you

- **Plugins** (znap): zsh-autosuggestions (history + completion strategy),
  zsh-syntax-highlighting.
- **fzf keybindings**: `Ctrl-R` fuzzy history, `Ctrl-T` fuzzy file insert (ripgrep-listed,
  bat preview), `Alt-C` fuzzy cd (eza tree preview).
- **Modern CLI aliases** (guarded — fall back to classic tools when absent): `ls`/`ll`/`la`/
  `l`/`tree` → eza with icons, `cat` → bat. `find` is deliberately NOT aliased to fd
  (incompatible CLIs); use `fd` directly.
- **git**: delta as pager (syntax-highlighted diffs; configured in `~/.gitconfig`, outside
  this repo's snapshots).
- **Functions** (`config/80-functions.zsh`): `cheat` (quick reference for tmux/Ghostty
  navigation + split keys, fzf keys, aliases, functions; `cheat keys|aliases|funcs`), `manigen` (clone repo URLs flat into
  the cwd, then generate/refresh `mani.yaml` from every git dir found there —
  run with no args to just rescan after a manual clone/init; skips `Work/`),
  `rename-tab`, `benchmark` (hyperfine with default warmup), `logit` (tee a command's
  output to `~/.cache/captures/*.md`, each line timestamped and labelled
  `[STDOUT]`/`[STDERR]` — self-prunes after 30 days; `logit -p` for the plain unlabelled
  merge, `logit -l` prints the newest path), `toggle-headroom` (flips
  `ANTHROPIC_BASE_URL`/`OPENAI_BASE_URL` for the whole shell to route through the
  local Headroom proxy, port from `$HEADROOM_PORT` default 8787; call again to
  unset), `claude` / `codex` (wrappers: check the proxy's `/readyz`, then route
  through it via `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`; abort with `headroom
  install status` if the proxy is down — `HEADROOM_OFF=1` bypasses,
  `--version`/`--help` skip the check. Once routed, launch is backed by a tmux
  session: resumes the matching session for the current directory — git repos
  match by `git rev-parse --show-toplevel`, so any subdirectory finds it —
  prompts via `fzf` if several match, or starts a new one if none do; already
  inside tmux it runs in the current pane instead, so split a pane and start an agent there;
  `HEADROOM_OFF=1`/`--version`/`--help` skip tmux too), `agy` (Antigravity CLI: same tmux
  resume/create, but no Headroom routing; `-p`/`--print`/subcommands stay direct), `bentopdf start|stop|update|status`
  (manages the `bentopdf-service` Docker container, port 3000; `start` creates
  it on first run with `--restart unless-stopped`, `update` pulls the latest
  image and recreates it), `tokens list|show NAME|set NAME` (view
  keychain-backed secrets from `config/local-secrets.zsh` masked to their
  last 4 chars, print one in full, or set one via hidden prompt +
  `security add-generic-password`). Plus
  `ghosttytheme` (`config/85-ghosttytheme.zsh`) — Ghostty color-scheme switcher
  with fzf picker (writes an unmanaged `theme` file that `config.ghostty` includes).
- **Navigation**: zoxide (`z`/`zi`, `j` alias).

## Everyday commands

```sh
bin/install.sh           # apply changes (idempotent; installs missing, never upgrades)
bin/update.sh            # upgrade brew packages + uv/cargo tools (see note below)
bin/doctor.sh            # health check
bin/snapshot.sh          # back up before risky edits
bin/rollback.sh <ts>     # restore a snapshot (bin/rollback.sh lists them; `latest` works too)
bin/uninstall.sh         # restore the most recent snapshot
```

`mise.toml` pins dev tools (pre-commit, shellcheck, shfmt) and wraps the above as tasks:
run `mise trust && mise install` once, then `mise tasks` to list. `mise run install|update|doctor|snapshot|rollback <ts>`
call the `bin/` scripts; `mise run syntax|lint|fmt-check|check|startup` are the verification helpers
(`check` = syntax + shellcheck + shfmt diff + `pre-commit run --all-files`; `mise run fmt` rewrites
`bin/*.sh` with shfmt). `config/60-tools.zsh` runs `mise activate zsh`, so pinned
tools and `[env]` load per directory in any repo with a mise config.

## Pre-commit hooks

`.pre-commit-config.yaml` guards the repo: `zsh -n` on the config fragments, `bash -n` on
`bin/*.sh`, plus whitespace/EOF/merge-conflict checks. Activate once per clone:

```sh
pre-commit install        # wires .git/hooks/pre-commit; hooks then run on every commit
pre-commit run --all-files # run them on demand
```

The external `pre-commit-hooks` repo is pinned by `rev:` so everyone runs the same, reviewed
hook code (and a compromised upstream can't execute until you opt in). Bump that pin
**deliberately** — it's not part of `bin/update.sh`, since it changes code that runs in your
commit path and deserves a look before it lands:

```sh
pre-commit autoupdate     # rewrite rev: to the latest tags; review, then commit
```

## Machine-specific / secrets

Copy `config/99-local.zsh.example` to `~/.config/zsh/99-local.zsh`. It's gitignored and loads
last, so it overrides anything. Never put literal secrets or per-machine paths in tracked files.

`config/local-secrets.zsh` **is** tracked — it holds only dynamic lookups (macOS keychain,
`docker context inspect`) that resolve at shell start, never a literal secret value.
`99-local.zsh` sources it. Add a new var there only if the value is derived, not hardcoded;
anything that can't be derived goes in the untracked `99-local.zsh` instead.

## Extras (versioned here, not installed)

Adjacent configs kept under version control that `install.sh` does **not** touch and never
copies into place:

- `extras/claude/GLOBAL_CLAUDE.md` — backup of my machine-global Claude Code rules
  (live source: `~/.claude/CLAUDE.md`; also a public
  [gist](https://gist.github.com/BaankeyBihari/f394e97eb10cfe17e031567205800517)). Snapshot
  only — it may lag the live file; edit `~/.claude/CLAUDE.md` and re-copy to resync.
