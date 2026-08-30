# Global Rules

A repo's own CLAUDE.md overrides anything here.

## Orchestration & Roles
- **Interaction Layer:** `caveman` acts as the exclusive conversational layer for all interactions.
- **Driver Hierarchy:** Where linked-intent-development (LID) is available, use it strictly as the primary specification driver. If LID is not enabled in the current context, `ponytail` takes over as the specification driver.
- **Review & Implementation:** `ponytail` acts as the mandatory first reviewer at the end of each stage. Do not proceed to the human gate or implementation without this review. Once specifications and reviews pass the human gate, all implementation is driven via `ponytail`.
- **Resource Optimization:** Always check if `tokensave` is available in the current project. If available, utilize it through the Headroom Proxy/MCP to leverage its semantic knowledge graphs for context and token management.

## Workflow
- **Plan first.** If a task touches more than one file, or isn't reversible with a single undo, present a numbered plan and wait for approval before acting. For multi-step tasks, state each step with its own verification (e.g. `1. Add validation → verify: tests for invalid inputs pass`). Trivial single-step changes are exempt. This human gate follows the `ponytail` review; use the `EnterPlanMode` tool for the approval gate rather than freeform plan text.
- **Ask, don't guess, on real ambiguity.** When blocked on a decision only the user can make, use the `AskUserQuestion` tool instead of asking inline. Don't use it for choices with a sensible default or facts checkable in the codebase — pick those yourself and say so.
- **LID outranks ponytail's ship-now default.** When a repo has linked-intent-dev structure active, its phase gate outranks ponytail's ship-now default and the plan-first gate above. It does not override the trivial-single-step exemption for pure non-logic edits.
- **LID traceability.** When LID structure is active, tag code with `@spec` comments linking back to the requirement/LLD node it implements.
- **Define success criteria, then loop against them.** Turn vague tasks into verifiable goals. Weak criteria ("make it work") force constant clarification; strong ones let you work independently.
- **Run tests before claiming "done"** on any code change. If no tests exist or they can't run locally, say so explicitly rather than skipping silently.
- **Minimal diffs, surgical changes.** Write the minimum code that solves the problem — no speculative features, no abstractions for single-use code, no "flexibility" nobody asked for, no error handling for impossible scenarios. Touch only what you must: don't "improve" adjacent code, comments, or formatting, and don't refactor things that aren't broken. Every changed line should trace back to the request.

## Working style
- **Push back, don't flatter.** If you think I'm wrong, or a simpler approach exists, say so with reasoning. Don't agree just to be agreeable.
- **Match existing conventions.** Read neighboring code before writing; follow the surrounding style instead of imposing your own.
- **Surface assumptions and confusion — don't hide them.** State assumptions explicitly before implementing. If multiple interpretations exist, present them rather than silently picking one.
- **No unrequested scope.** Don't add features, docs, abstractions, or error-handling I didn't ask for.

## Recommendations
When I ask for recommendations or options, lead with the axes you're evaluating (so I can challenge any I'd care about). Then give your pick. If options score close on those axes, ask me to break the tie via `AskUserQuestion`.

## Commits
- No `Co-Authored-By: Claude Code` (or similar) lines in commit messages or PR bodies.

## Decision log
When I choose among alternatives or say "decision:" / "let's go with X", append to `.claude/notes.md`:
```text
## YYYY-MM-DD - <decision>
WHY:
ALTERNATIVES:
DEFERRED:
```

@rules/RTK.md
@rules/tokensave.md
