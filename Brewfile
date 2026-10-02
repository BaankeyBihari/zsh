# Brewfile — source of truth for tools provisioned on a fresh machine.
# Applied by bin/install.sh via `brew bundle --file=Brewfile`.

# Core shell + prompt
brew "zsh"
brew "git"
brew "starship"
brew "tmux"        # backs `claude`/`codex` sessions in config/80-functions.zsh

# Rust toolchain
brew "rust"
brew "cargo-update" # `cargo install-update --all` — upgrades cargo-installed binaries; wired in bin/update.sh

# AWS — granted provides `assume`, which config/.zshenv aliases unconditionally.
brew "granted"
brew "awscli"

# Git/GitHub
brew "gh"
brew "pre-commit"   # manage git pre-commit hooks (.pre-commit-config.yaml)
brew "mise"         # mise.toml: pinned dev tools + `mise run` tasks
brew "mani"         # run commands / sync config across multiple repos
brew "flock"        # file locks for mani tasks (mani/tasks.yaml serializes gita registration)

# Productivity
brew "bat"         # cat with syntax highlighting; guarded `cat` alias in 70-aliases.zsh
brew "delta"       # syntax-highlighted git pager (wired via git config --global)
brew "eza"         # modern ls; guarded ls/ll/la/tree aliases in 70-aliases.zsh
brew "fd"          # fast find alternative (NOT aliased to find — incompatible CLIs)
brew "fzf"
brew "hyperfine"   # CLI benchmarking; `benchmark` wrapper in config/80-functions.zsh
brew "ripgrep"     # rg; also drives FZF_DEFAULT_COMMAND in config/60-tools.zsh
brew "tldr"        # command cheatsheets
brew "tree"
brew "zoxide"   # smarter cd; provides `z`/`zi` (+ `j` alias) — init in config/60-tools.zsh

# Python tooling
brew "uv"
brew "pipenv"

# Containers — colima is the Docker Desktop-free runtime the docker CLI drives.
brew "colima"
brew "docker"
brew "docker-compose"
brew "docker-buildx"
brew "docker-credential-helper"
brew "ducker"      # TUI for managing docker containers/images (k9s-equivalent for docker)

# Kubernetes
brew "kubernetes-cli"
brew "k9s"
brew "stern"

# Infra
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"
brew "cloud-nuke"

# LocalStack — lstk is the CLI, LOCALSTACK_AUTH_TOKEN comes from the keychain via ~/.config/tokens/map.yaml
tap "localstack/tap"
cask "localstack/tap/lstk"

# Terminal
cask "ghostty"    # config/85-ghosttytheme.zsh drives it — must be provisioned

# Nerd Font — required glyphs for the starship pastel-powerline prompt.
# Ghostty: ghostty/config.ghostty sets `font-family = "MesloLGS Nerd Font Mono"`.
cask "font-meslo-lg-nerd-font"

# Apps
cask "jordanbaird-ice"
cask "maccy"
cask "sublime-text"
cask "swift-quit"

# Google Antigravity — agent orchestration platform, IDE, and terminal CLI.
cask "antigravity"        # Antigravity.app — agent orchestration platform
cask "antigravity-ide"    # AI coding agent IDE
cask "antigravity-cli"    # terminal interface for Antigravity agents

# Google Gemini — desktop assistant app (Gemini.app).
cask "google-gemini"
