# Use AskUserQuestion only for fixed-choice prompts where all valid responses are finite and known in advance

Every interactive prompt that has a finite, pre-known set of valid responses and requires no follow-up prose uses `AskUserQuestion`. All other interactions remain free-form conversation.

The criterion: **Use `AskUserQuestion` when the set of valid responses is finite, known before the prompt is shown, and no response requires follow-up prose.**

Prompts migrated under this rule: item-by-item migration gate (Apply / Skip / Apply All Remaining / Stop Migration), milestone assignment yes/no, dependency inference bulk confirm (Accept all / Cherry-pick / Reject all), refine queue selection (multiSelect for ≤ 4 items), between-item continue/stop, in-progress resume-vs-new-pick, Status field customization choice, Issue template replacement choice, and label disambiguation for unclear `type:*`, `priority:*`, and `effort:*` classifications.

Prompts explicitly left as free-form: plan approval in `execute-item` (users routinely answer "request changes" or "yes but move X first"), spike findings sign-off (the user's free-text response IS the edits to the document), rank-order confirmation in `add-item` and `refine-item` (users frequently add rationale or redirect), and the apply-all-changes gate in `refine-item` (partial acceptance with prose adjustments is common).

## Considered Options

**All interactive prompts → AskUserQuestion** — rejected because `AskUserQuestion` renders as a structured widget. Conversational prompts where "request changes" or "yes but do X first" are normal responses would force users into the "Other" free-text escape hatch on every interaction, degrading UX relative to plain prose.

**All prompts remain free-form** — rejected because fixed-choice gates (Y/N/All/Stop) that rely on parsing typed replies are fragile: the executing AI must interpret free text and can misread ambiguous input. `AskUserQuestion` eliminates that parsing entirely.
