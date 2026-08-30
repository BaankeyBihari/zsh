# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy for shell commands (cuts up to 90% of bash output).

## Rule

Always prefix shell commands with `rtk`.

- **Claude Code**: a `PreToolUse` hook rewrites every `Bash` call automatically — transparent, 0 token overhead, no manual prefixing needed. Example: `git status` → `rtk git status`.
- **Antigravity / Gemini CLI**: no such hook — prefix every shell command yourself.

Examples:

```bash
rtk git status
rtk cargo test
rtk ls src/
rtk grep "pattern" src/
rtk find "*.rs" .
rtk docker ps
rtk gh pr list
```

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Why

RTK filters and compresses command output before it reaches the LLM context, cutting up to 90% of the bash output on common operations.
