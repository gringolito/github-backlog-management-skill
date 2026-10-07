# Skills do not name harness tools

Supersedes [ADR 0002](0002-askuserquestion-for-fixed-choice-prompts.md).

Skills describe what to do and when the user decides, never which tool does it. That covers `AskUserQuestion` and `TaskCreate`, as well as `gh` and GraphQL calls. The agent chooses how to ask: a structured prompt when the harness offers one, plain conversation otherwise.

Skills ask the user only in two cases. The first is when the agent isn't confident about what to do, because the request is ambiguous or the evidence doesn't settle it. The second is when the decision belongs to the user, such as picking between a few valid options. Everything else proceeds without a confirmation gate, including writes to GitHub. This removes the fixed-choice prompts between items that ADR 0002 routed through `AskUserQuestion`, and the blanket "confirm before writing" step that replaced them.

## Considered options

Mandating `AskUserQuestion` for fixed-choice prompts (ADR 0002) was rejected. It ties skills to one harness's tool names, so they break or mislead elsewhere. The parsing fragility it solved came from prompts between items, which no longer exist.

One confirmation before every write to GitHub was rejected. It asks the user to approve work the agent was already sure about, which trains them to approve without reading. A question is worth the interruption only when the agent is unsure or the user has a real choice to make.

Leaving prompt mechanics to each skill author was rejected. Naming tools is the thing that drifts, and a skill that says only what it needs from the user stays correct when tools change.
