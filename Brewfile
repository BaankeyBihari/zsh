# Brewfile — source of truth for tools provisioned on a fresh machine.
# Applied by bin/install.sh via `brew bundle --file=Brewfile`.

# Core shell + prompt
brew "zsh"
brew "git"
brew "starship"

# Version managers used by config/60-tools.zsh
brew "fnm"
brew "pyenv"

# AWS — granted provides `assume`, which config/.zshenv aliases unconditionally.
brew "granted"
brew "awscli"

# Git/GitHub
brew "gh"
brew "pre-commit"   # manage git pre-commit hooks (.pre-commit-config.yaml)

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

# Kubernetes
brew "kubernetes-cli"
brew "k9s"
brew "stern"

# Local LLMs
brew "ollama"

# Terminal + Python distribution
cask "ghostty"    # config/85-ghosttytheme.zsh drives it — must be provisioned
cask "iterm2"
cask "miniconda"

# Nerd Font — required glyphs for the starship pastel-powerline prompt.
# Set iTerm2 font to "MesloLGS Nerd Font" (Profiles → Text).
cask "font-meslo-lg-nerd-font"

# Apps
cask "maccy"
cask "sublime-text"

# Google Antigravity — agent orchestration platform, IDE, and terminal CLI.
cask "antigravity"        # Antigravity.app — agent orchestration platform
cask "antigravity-ide"    # AI coding agent IDE
cask "antigravity-cli"    # terminal interface for Antigravity agents

# Google Gemini — desktop assistant app (Gemini.app).
cask "google-gemini"
