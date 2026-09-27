# Machine-local env vars safe to track: no literal secrets, only dynamic lookups (keychain,
# docker context) resolved at shell start. Installed to the ZDOTDIR root and sourced by
# 99-local.zsh (gitignored), which still exists for anything that must never be tracked.

# ducker (docker TUI) looks at /var/run/docker.sock only, ignoring the active docker context.
# colima doesn't use that path, so point DOCKER_HOST at whatever context is actually active.
export DOCKER_HOST="$(docker context inspect -f '{{.Endpoints.docker.Host}}' 2>/dev/null)"

# HuggingFace CLI token, read by huggingface-cli/transformers outside this repo.
export HF_TOKEN="$(security find-generic-password -a "$USER" -s hf-access-token -w 2>/dev/null)"
# Claude Code feature flag enabling the ToolSearch/deferred-tools mechanism.
export ENABLE_TOOL_SEARCH="true"
# Bitwarden Secrets Manager (bws CLI) access token for pulling project secrets.
export BWS_ACCESS_TOKEN="$(security find-generic-password -a "$USER" -s bws-access-token -w 2>/dev/null)"

# LocalStack Pro auth token, read by the localstack CLI.
export LOCALSTACK_AUTH_TOKEN="$(security find-generic-password -a "$USER" -s localstack-auth-token -w 2>/dev/null)"
