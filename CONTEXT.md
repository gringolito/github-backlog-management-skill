# Backlog Management

The domain of this plugin: managing a software backlog entirely through GitHub-native
primitives (Issues, Projects v2, Milestones, Labels). The language below is the shared
vocabulary every skill, agent, and doc in this repo must speak.

## Language

### Substrate

**Issue**:
The GitHub Issue — the substrate for every Backlog Item. There is no separate record:
"Backlog Item" is the domain reading of an Issue tracked in the Project.

**Project**:
The single GitHub Projects v2 board linked to the repo, titled `Backlog`. Holds every Backlog
Item as a card, carries the Status field and Rank, and is the source of truth for ordering.
One repo, one Project.

### Items

**Backlog Item**:
The umbrella term for any Issue tracked on the backlog. Splits on one axis into a
**Workable Item** and a **Non-Workable Item**.

**Workable Item**:
A Backlog Item representing real, buildable work — must pass INVEST and carry a
`type:*`, `priority:*`, and `effort:*` label. The opposite of a Non-Workable Item.
Synonym: _Deliverable_.
_Avoid_: work item (reads like a generic synonym for "task" and obscures the workable-vs-non-workable distinction)

**Non-Workable Item**:
A Backlog Item that is never built — excluded from all counts, metrics, release scope, and
execution. The branch opposite a Workable Item. Today its only kind is the **Stub**; future
kinds (e.g. an **Epic** — a container that organizes work without itself being built) belong
here too.

**Stub**:
The one current kind of Non-Workable Item: the encapsulation of an **External Blocker** — an
out-of-team-control constraint recorded so it can block Workable Items. Carries
`type:external-blocker` and is created only by `/add-external-blocker` (cleared by `/resolve-external-blocker`).
_Avoid_: using "Stub" as a synonym for the whole Non-Workable Item category — it is one kind of it

### Classification

**Type**:
The category of work a Workable Item represents — exactly one `type:*` label: `feature`,
`bug`, `security`, `performance`, `dx`, `tech-debt`, `reliability`, `compliance`, `spike`, or
`external-blocker`. `type:external-blocker` is reserved for Stubs and is never assigned to a
Workable Item.
_Avoid_: bucket (the retired name for this concept), category

**Priority**:
The severity classification of a Workable Item, one of `P0`–`P3`. Answers "how badly does
this matter?" — not "what do we do next?". Independent of Rank.
_Avoid_: importance, urgency

**Effort**:
The rough size estimate of a Workable Item, one `effort:*` label: `XS`, `S`, `M`, `L`, `XL`.
The concrete output of the "Estimable" INVEST check.
_Avoid_: estimate, size, story points (the label is "Effort")

**INVEST**:
The six-criterion quality bar every Workable Item must pass to enter the Queue: Independent,
Negotiable, Valuable, Estimable, Small, Testable. Enforced at creation and Refinement by the
invest-gate.

**needs-clarification**:
The operational label marking a Backlog Item that fails the quality bar and awaits Refinement.
The queue `/refine-backlog` works from. Removed only after a passing INVEST gate.

### Ordering & lifecycle

**Backlog**:
The full collection of Backlog Items tracked in the linked Project. An umbrella, *not* a
lifecycle state — there is no "Backlog" Status.
_Avoid_: Backlog (as a Status value — the states are Todo / In Progress / Done)

**Status**:
The single custom field on the Project, and the lifecycle state of a Backlog Item: one of
`Todo`, `In Progress`, `Done`. The only Project-level field — Type, Priority, and Effort live
as repo labels, not Status.

**Rank**:
The manual execution order of items in the Project's Todo column; topmost wins. Answers
"what do we do next?". The sole input to execution order — `/execute-backlog-item` reads
Rank only and ignores Priority for ordering.
_Avoid_: position (the GitHub Projects API term), priority (a different concept)

**Queue**:
The Rank-ordered list of `Todo` items awaiting execution. `/execute-backlog-item` pulls from
the top of the Queue.
_Avoid_: Todo column (acceptable informally, but "Queue" names the ordered intent)

### Releases

**Release**:
A versioned increment of work — a scope of Backlog Items, a target version, and a due date.
The canonical planning unit. Realized as a **Milestone**; culminating in a published
**Release artifact** at closure.
_Avoid_: sprint, iteration

**Milestone**:
The GitHub object that realizes a Release (carries `due_on`, scope, and open/closed state).
Use "Milestone" when you mean the concrete GitHub thing specifically; use "Release" when you
mean the planning concept.

**Active Release**:
The Release work currently targets by default: the earliest open Milestone by `due_on`,
tie-broken by lowest version parsed from the title (`v1.2.0` < `v1.3.0`), falling back to
Milestone `number`. `/execute-item`, `/add-item`, `/migrate`, and `/release-status` all
resolve to this when no Release is named. When a Release name is given, it is matched by
case-insensitive title substring, then by stripping a leading `v` from both sides.
Resolved at runtime by `bin/resolve-milestone` (no-arg → Active Release; positional arg →
named Release; `--exclude "<title>"` → Active Release skipping one Milestone by exact title).
Output: `{"number": N, "title": "...", "due_on": "..."}` — `due_on` is `null` when unset.
_Avoid_: current milestone, current release

**Release artifact**:
The published GitHub Release — release notes plus a version tag — cut when a Release closes.
The end product of `/close-release`, distinct from the Release (planning unit) that produced it.
_Avoid_: using bare "Release" for the artifact when the planning unit is also in scope

### Relationships

**Dependency**:
A directed relationship between two Issues, recorded via GitHub Issue Dependencies
(`blocked_by` / `blocking`). The source of truth for whether an item is gated — never mirrored
into the issue body. A blocked item is skipped by `/execute-backlog-item`.
_Avoid_: link, relation

**Blocker**:
The upstream Issue in a `blocked_by` edge — what must close before the blocked item can
proceed. May be a Workable Item or a Stub.

**External Blocker**:
A Blocker that is a Stub — an out-of-team-control constraint. The role a `type:external-blocker`
Stub plays. Created by `/add-external-blocker`; cleared by `/resolve-external-blocker`.

**Sub-issue** / **Parent**:
Hierarchical decomposition recorded via GitHub `sub_issues`. A sub-issue does NOT inherit its
parent's Release, Priority, Effort, Type, or Rank — the two are independent. A sub-issue has at
most one parent.
_Avoid_: epic (for the parent), task (for the sub-issue) unless independently defined

### Activities

**Audit**:
The read-only, portfolio-wide quality sweep: checks INVEST compliance, required labels,
dangling Dependencies, and cross-Project smells, then emits `gh` fix snippets the user can run
— it never mutates. Performed by `/audit` (engine: the backlog-auditor).
_Avoid_: validate, validation as the name of the activity

**Health**:
The read-only strategic portfolio report: distribution by Type / Priority / Effort, age
cohorts, overdue P0/P1, stale In-Progress items, and metadata debt. The "is the portfolio
balanced?" lens, across all open items. Produced by `/health`.

**Release Status**:
The read-only operational dashboard for a single Release: item counts by Status, blocked
items, and items without an Effort estimate. The "how is this Release tracking?" lens. Produced by
`/release-status`.

**Refinement**:
The mutating act of bringing an ambiguous Backlog Item up to standard — discovery dialogue,
body rewrite, INVEST gate, label/Rank/Dependency fixes, and clearing `needs-clarification`.
Run by `/refine` (session over many items) and `/refine-item` (a single item).
_Avoid_: grooming

**Execution**:
Picking the topmost unblocked Workable Item from the Queue and carrying it through to a PR.
Obeys Rank, skips blocked items, and descends into sub-issues. Run by `/execute-item`.

**Scope Completeness Review**:
The verification step entered when a picked Backlog Item has sub-issues and all are closed.
Cross-references the parent's Acceptance Criteria against closed sub-issues, presents a
coverage analysis, then either closes the parent (scope complete) or creates new sub-issues
for uncovered gaps. Part of `/execute-item`; triggered automatically, never run standalone.

**Migration**:
The one-time bulk import of an existing `BACKLOG.md` into Issues — normalizes labels, skips
Done items (historical work is not migrated), and offers opt-in Dependency inference. Run by
`/migrate`.
_Avoid_: import (acceptable informally; "Migration" is the named activity)

## Flagged ambiguities

**Priority vs Rank** — these are independent and must never be conflated. Priority is a
severity _label_ (P0–P3); Rank is the _queue order_ in the Todo column. A P0 can sit below
a P2 in Rank if that's the deliberate order of work. Skills recommend keeping them roughly
consistent, but execution obeys Rank alone.

**Dependency vs Sub-issue** — a Dependency _blocks_: a blocked item is skipped in execution
until its Blocker closes. A Sub-issue relationship _decomposes_: execution descends into a
parent's sub-issues and picks the topmost unblocked one. A parent is not "blocked by" its
children, but you cannot execute a parent without first working its sub-issues. Decomposition
is not a Dependency.

**Status vs Release Status** — "Status" is the per-item Project field (Todo / In Progress /
Done). "Release Status" is the read-only dashboard reporting on a whole Release. Never shorten
"Release Status" to "Status."

**Audit vs Health vs Release Status** — three distinct read-only lenses, none of which mutate.
Audit checks _correctness_ (is the backlog well-formed?). Health checks _strategic shape_ (is
the portfolio balanced?). Release Status checks _operational progress_ (how is one Release
tracking?).

## Example dialogue

> **Dev:** The P0 is at the bottom of the Todo column — is that a mistake?
> **Lead:** No. Priority and Rank are independent. It's a P0 by severity, but it's blocked, so
> it sits low in Rank. Execution reads Rank, so it won't get picked until we re-rank it.
>
> **Dev:** Blocked by what? It has a sub-issue open.
> **Lead:** A sub-issue isn't a Blocker — that's decomposition, not a Dependency. It's blocked
> by #44, which is an External Blocker: a Stub for the vendor API we're waiting on. It's not a
> Workable Item, so it never shows up in counts — it just gates this one.
>
> **Dev:** Should I refine it now?
> **Lead:** It's not flagged `needs-clarification`, so it already passed INVEST. Leave it. Run
> an Audit if you want to check the whole backlog is well-formed — but that won't change
> anything, it just emits fix commands.
