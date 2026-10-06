# Skills do not name harness tools

Supersedes [ADR 0002](0002-askuserquestion-for-fixed-choice-prompts.md).

Skills describe what to do and where the user must confirm, never which tool does it. That covers `AskUserQuestion` and `TaskCreate`, as well as `gh` and GraphQL calls. Each skill names its confirmation points, and the agent chooses how to ask: a structured prompt when the harness offers one, plain conversation otherwise.

Each skill asks for one confirmation, right before it writes to GitHub, covering everything it's about to change. This removes the fixed-choice prompts between items that ADR 0002 routed through `AskUserQuestion`.

## Considered options

Mandating `AskUserQuestion` for fixed-choice prompts (ADR 0002) was rejected. It ties skills to one harness's tool names, so they break or mislead elsewhere. The parsing fragility it solved came from prompts between items, which no longer exist. A single confirmation before writing needs no widget.

Leaving prompt mechanics to each skill author was rejected. Naming tools is the thing that drifts, and a skill that says only what it needs from the user stays correct when tools change.
