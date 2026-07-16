---
name: spike
description: Execute a spike's investigation, findings document, and follow-on item creation end-to-end through PR. Use once a type:spike Item is selected, via /pick-item's hand-off or run directly.
---

# spike

You are an AI agent acting as a development lead, conducting a spike investigation. A spike's deliverable is knowledge, not production code. Its outputs are:

- A findings document
- A recommendation
- And any follow-on backlog items required to implement the recommendation.

Any code written during the spike exists only to answer the investigation question and should be considered disposable unless explicitly approved otherwise.

The goal is information gathering, risk reduction, or proving a concept. It is an exploration phase, meaning quick-and-dirty code or purely theoretical architectural research is entirely acceptable.

When you finish, output a summary of your findings, a recommendation on the best path forward, and a rough estimate of how difficult the final implementation will be.

## Workflow

1. Create and check out branch `spike/<slug>`.
2. Investigate the question framed in `What` / `Why`. Prototyping is permitted in throwaway branches but is NOT the deliverable.
3. Author the findings document at `docs/spikes/####-<slug>.md`, use sequential numbering (e.g. `0001-slug.md`, `0002-slug.md`, etc.), with these sections (in this order):
   - `## Question`: restate the spike's investigative question
   - `## Approach`: what was investigated, sources consulted, prototypes built
   - `## Findings`: what was learned, including dead-ends
   - `## Recommendation`: the recommended path forward (or "abandon — see Findings")
   - `## Follow-on Work`: bulleted list of new backlog items this spike surfaces (filled in step 6)
4. Present a concise findings summary and recommendation. Pause and wait for explicit user approval before modifying the findings document or creating follow-on backlog items.
5. Propose follow-on backlog items for each piece of surfaced work. Create one backlog item per independently deliverable piece of work. Avoid combining unrelated implementation tasks into a single issue. Present the full list to the user and wait for explicit approval per item (some may be discarded).
6. Create the approved follow-ons by invoking `/add-item` for each in sequence: if the spike has a parent, pass that parent's issue number so each follow-on becomes a peer sub-issue of it; otherwise create the follow-on as a standalone top-level item. Record the resulting issue numbers and update the `## Follow-on Work` section of the findings document with `#<n>` references.
7. The spike's PR typically contains only the findings document. Code changes (if any) belong in the follow-on items, prototypes are throwaway code.
8. Confirm the findings document exists at `docs/spikes/<number>-<slug>.md` with all required sections, every approved follow-on was created and referenced in `## Follow-on Work`.
9. Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body. Push the branch.
10. Open a Pull Request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one. PR body MUST include `Closes #<issue-number>` and list every follow-on item created (`#<new-issue-number> — <title>`), so reviewers can audit that the surfaced work landed in the backlog. It is expected for a spike PR to contain no code changes.
11. Print: issue URL/number, PR URL/number, branch name, assignee, final Project Status, follow-on items created.
12. STOP. This item's run is complete.

## Rules & Constraints

- Do NOT make assumptions, when in doubt ask questions, one at a time, until reaching full understand of objective and the scope
- Do NOT proceed past findings without explicit user sign-off
- Do NOT close the issue manually, always rely on `Closes #N` in the PR
- Keep the PR focused into the findings document only
