---
name: spike
description: Execute a spike's investigation, findings document, and follow-on item creation end-to-end through PR. Use once a type:spike Item is selected, via /pick-item's hand-off or run directly.
---

# spike

You are an AI agent acting as a development lead, conducting a spike investigation.

A spike's deliverable is knowledge, not production code. Outputs:

- A findings document
- A recommendation
- Follow-on backlog items to implement the recommendation

Any code written during the spike exists only to answer the investigation question and is throwaway unless explicitly approved otherwise.

The goal is information gathering, risk reduction, or proof of concept. Quick-and-dirty code and purely theoretical architectural research are both fine.

## Workflow

1. Create and check out branch `spike/<slug>`.
2. Investigate the question framed in `What` / `Why`. Prototyping is permitted in throwaway branches but is NOT the deliverable.
3. Author the findings document at `docs/spikes/####-<slug>.md`, using sequential numbering (e.g. `0001-slug.md`, `0002-slug.md`), with these sections in order:
   - `## Question`: restate the spike's investigative question
   - `## Approach`: what was investigated, sources consulted, prototypes built
   - `## Findings`: what was learned, including dead-ends
   - `## Recommendation`: the recommended path forward (or "abandon; see Findings")
   - `## Follow-on Work`: bulleted list of new backlog items this spike surfaces (filled in step 6)
4. Present a concise findings summary and recommendation. Pause and wait for explicit user approval before modifying the findings document or creating follow-on backlog items.
5. Propose follow-on backlog items for each piece of surfaced work. Create one backlog item per independently deliverable piece of work. Do not combine unrelated implementation tasks into a single issue. Present the full list and wait for explicit approval per item (some may be discarded).
6. Create the approved follow-ons by invoking `/add-item` for each in sequence: if the spike has a parent, pass that parent's issue number so each follow-on becomes a peer sub-issue; otherwise create it as a standalone top-level item. Record the resulting issue numbers and update `## Follow-on Work` with `#<n>` references.
7. The spike's PR contains only the findings document. Code changes belong in follow-on items; prototypes are throwaway.
8. Confirm the findings document exists at `docs/spikes/<number>-<slug>.md` with all required sections, and every approved follow-on was created and referenced in `## Follow-on Work`.
9. Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body. Push the branch.
10. Open a pull request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one. PR body MUST include `Closes #<issue-number>` and list every follow-on item created (`#<new-issue-number>: <title>`), so reviewers can audit that surfaced work landed in the backlog.
11. Print: issue URL/number, PR URL/number, branch name, assignee, final Project Status, follow-on items created.
12. STOP. This item's run is complete.

## Constraints

- Do NOT assume; when in doubt ask clarifying questions one at a time until the objective and scope are clear
- Do NOT proceed past findings without explicit user sign-off
- Do NOT close the issue manually; always rely on `Closes #N` in the PR
- Keep the PR limited to the findings document
