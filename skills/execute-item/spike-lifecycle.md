# Spikes

A spike's deliverable is **knowledge**, a findings document plus the follow-on backlog items it surfaces, not a shippable feature. Apply this flow:

1. **Investigate** the question framed in `### What` / `### Why`. Prototyping is permitted in throwaway branches but is NOT the deliverable.
2. **Author the findings document** at `docs/spikes/####-<slug>.md`, use sequential numbering (e.g. `0001-slug.md`, `0002-slug.md`, etc.), with these sections (in this order):
   - `## Question`: restate the spike's investigative question
   - `## Approach`: what was investigated, sources consulted, prototypes built
   - `## Findings`: what was learned, including dead-ends
   - `## Recommendation`: the recommended path forward (or "abandon — see Findings")
   - `## Follow-on Work`: bulleted list of new backlog items this spike surfaces (filled in step 4)
3. **Present the findings summary to the user** for confirmation/edits before the document is finalized. Do NOT proceed until the user signs off on the findings.
4. **Propose follow-on backlog items** for each piece of surfaced work — one per item — with title, What, Why, draft Acceptance Criteria, and suggested `type:*` / `priority:*` / `effort:*` labels. Present the full list to the user and wait for explicit approval per item (some may be discarded).
5. **Create the approved follow-ons** by invoking `/add-item` for each in sequence:
   - If the spike has NO parent → create as **standalone top-level items**
   - If the spike HAS a parent → pass the **spike's parent issue number** so the new items become **peer sub-issues of the spike**
   - Record the resulting issue numbers and update the `## Follow-on Work` section of the findings document with `#<n>` references
6. The spike's PR diff is typically only the findings document. Code changes (if any) belong in the follow-on items, not in the spike's PR.

Additionally:

- Confirm the findings document exists at `docs/spikes/<number>-<slug>.md` with all required sections
- Confirm every approved follow-on was created and that its issue number is referenced in the `## Follow-on Work` section
- Confirm follow-on parentage matches the rule in Step 8 (standalone if spike had no parent; peer sub-issues of the spike's parent otherwise)

If a PR is needed, it is typically includes the findings document only:

- PR body MUST list every follow-on item created (`#<new-issue-number> — <title>`), so reviewers can audit that the surfaced work landed in the backlog
- It expected for a spike PR to contain no code changes
