#!/usr/bin/env bash
# uninstall.sh — convenience wrapper: roll back to the most recent snapshot, which
# removes the repo-managed copies and restores the pre-install config.
#
# This does NOT uninstall Homebrew packages — those are shared system state. Remove
# them manually with `brew uninstall` / `brew bundle cleanup` if desired.

set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$REPO/bin/rollback.sh" latest
