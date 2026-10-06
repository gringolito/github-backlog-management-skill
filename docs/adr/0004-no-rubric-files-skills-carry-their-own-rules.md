# Skills carry their own rules; per-repo facts live in the repo's agent instructions

Supersedes [ADR 0001](0001-rubrics-live-in-agents.md).

There is no shared rubric, reference file, or custom agent to house one. Each skill states the few rules it needs in a sentence or two: INVEST in the skills that write items and in `audit`, the body shape in `add-item`, `refine-item` and `audit`, and the `blocked_by` API wherever dependencies are recorded. The model already knows INVEST, can weigh where an item belongs in the Queue, and notices dependencies in prose, so what survives is only the part it can't infer, such as the epic exemption from INVEST.

The two facts that vary per repository, its Project and its label vocabulary, live in the consuming repo's `CLAUDE.md` or `AGENTS.md`. `setup` writes them into a short section the user can edit, labels included. Skills read that section and point the user to `setup` when it's missing.

The `github-backlog-management` routing skill goes with this. It only repeated each skill's `description`, which the harness already routes on, and carried no domain knowledge.

## Considered options

Keeping rubrics in custom agents (ADR 0001) was rejected. The agents existed because earlier models needed a stateless executor with a fixed rubric. Current models apply the rubric directly, and each agent added a hand-off, a JSON contract, and a second place to keep in sync.

Per-skill or shared `reference.md` files were rejected for the reason ADR 0001 already gave: a file no runtime consumer reads is a drift hazard. A shared copy would also keep every skill coupled to one contract.

Keeping the label catalog in a shared file was rejected. Labels are per-repo facts, and users should be able to change them without editing the plugin.
