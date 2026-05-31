# zsh

My zsh environment, version-controlled. One repo, one install command, snapshot-based rollback.

Stack: **plain zsh + [starship](https://starship.rs) + [znap](https://github.com/marlonrichert/zsh-snap)**. macOS / Apple Silicon.

## Install (fresh machine)

```sh
git clone <this-repo> ~/zsh && ~/zsh/bin/install.sh
exec zsh
```

`install.sh` snapshots the current config, installs Homebrew + everything in the `Brewfile`
(zsh, git, starship, fnm, pyenv, fzf, iTerm2, miniconda), clones znap, symlinks the config into
place, then runs `doctor.sh`. It's idempotent — safe to re-run any time.

## Layout

```
home/      → ~/.zshenv, ~/.zprofile   (the only files placed in $HOME)
config/    → ~/.config/zsh/*          (.zshrc driver + NN-*.zsh fragments)
starship/  → ~/.config/starship.toml
Brewfile     provisioned tools/apps
bin/         install · snapshot · rollback · uninstall · doctor
snapshots/   timestamped backups (gitignored)
```

`~/.zshenv` points zsh at `~/.config/zsh/`; `.zshrc` sources the `NN-*.zsh` fragments in order.
To add config, drop a new numbered fragment — don't edit `.zshrc`.

## Everyday commands

```sh
bin/install.sh           # apply changes (idempotent)
bin/doctor.sh            # health check
bin/snapshot.sh          # back up before risky edits
bin/rollback.sh <ts>     # restore a snapshot (bin/rollback.sh lists them; `latest` works too)
bin/uninstall.sh         # restore the most recent snapshot
```

## Machine-specific / secrets

Copy `config/99-local.zsh.example` to `~/.config/zsh/99-local.zsh`. It's gitignored and loads
last, so it overrides anything. Never put secrets or per-machine paths in tracked files.
