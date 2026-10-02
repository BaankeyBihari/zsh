# Machine-local env vars safe to track: no literal secrets, only flags and dynamic lookups
# (docker context) resolved at shell start. Installed to the ZDOTDIR root and sourced (if
# present) by 99-local.zsh (gitignored), which still exists for anything that must never be tracked.

# ducker (docker TUI) looks at /var/run/docker.sock only, ignoring the active docker context.
# colima doesn't use that path, so point DOCKER_HOST at whatever context is actually active.
export DOCKER_HOST="$(docker context inspect -f '{{.Endpoints.docker.Host}}' 2>/dev/null)"

# Claude Code feature flag enabling the ToolSearch/deferred-tools mechanism.
export ENABLE_TOOL_SEARCH="true"

# Keychain-backed tokens (HF_TOKEN, BWS_ACCESS_TOKEN, LOCALSTACK_AUTH_TOKEN, ...) are exported
# by config/65-tokens.zsh from ~/.config/tokens/map.yaml.
