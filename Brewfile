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

# Productivity
brew "fzf"

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
cask "iterm2"
cask "miniconda"

# Apps
cask "maccy"
cask "sublime-text"
