# Spike 0001 — Evaluate replacing `gh` CLI with the official GitHub MCP server

- **Issue:** [#43](https://github.com/gringolito/github-backlog-management-skill/issues/43)
- **Labels:** `type:spike` · `priority:P3` · `effort:S`
- **Milestone:** v0.5.0
- **Date:** 2026-06-08

## Question

Should this plugin replace its reliance on the `gh` CLI (shelled out via `Bash`) with the
official [GitHub MCP server](https://github.com/github/github-mcp-server), bundled into the
plugin via `.mcp.json`? The deliverable is a coverage + UX assessment ending in one of three
verdicts: **migrate fully**, **migrate partially**, or **stay on `gh`**.

Sub-questions (from the issue):

1. Does the MCP server cover every distinct GitHub operation the plugin performs today?
2. Specifically — the **Issue Dependencies API**, the **Sub-issues API**, and the
   **Projects v2 GraphQL** operations?
3. How does install UX compare (today's `brew install gh && gh auth login` vs. Docker/binary + PAT)?
4. How does permission UX compare — can the MCP path reproduce the README's `yolo` and `safe` modes?
5. Does the MCP server reuse the existing `gh` token, or require a separate PAT / GitHub App?
6. What is the rough migration cost, and can it be staged?

## Approach

1. **Inventoried the plugin's actual `gh` surface** by grepping `skills/**/SKILL.md` and `bin/`:

   ```text
   gh project item-list   ×19      gh project item-edit   ×6
   gh issue edit          ×14      gh project field-list  ×5
   gh issue view          ×13      gh label list          ×5
   gh api …               ×12      gh issue create        ×5
   gh issue list          × 9      gh repo view           ×5
   gh project item-add    × 4      gh project view        ×3
   gh pr create           × 3      gh issue close         ×3
   gh issue comment       × 2      gh api graphql         ×2
   gh project create/link × 2      gh label create        ×1
   ```

   Plus the distinct `gh api` REST/GraphQL endpoints (milestones, sub-issues, dependencies,
   `updateProjectV2`, `releases/generate-notes`, `user`).

2. **Researched the GitHub MCP server** — its README, `docs/remote-server.md`,
   `docs/server-configuration.md`, the DeepWiki "Projects Toolset" page, the GitHub Changelog
   entries for Projects support (2025-10-14, 2026-01-28) and tool-specific configuration
   (2025-12-10), and the open feature-request issues that mark current gaps.

3. **Mapped each `gh` call to its MCP equivalent** (or lack thereof) to build the coverage matrix.

### Sources

- GitHub MCP server — repo & README: <https://github.com/github/github-mcp-server>
- Remote server & toolset URLs: <https://github.com/github/github-mcp-server/blob/main/docs/remote-server.md>
- Server configuration (`--toolsets`, `GITHUB_TOOLSETS`, `--read-only`): <https://github.com/github/github-mcp-server/blob/main/docs/server-configuration.md>
- Projects toolset reference: <https://deepwiki.com/github/github-mcp-server/3.6-projects-toolset>
- Changelog — Projects support: <https://github.blog/changelog/2025-10-14-github-mcp-server-now-supports-github-projects-and-more/>
- Changelog — new Projects tools / OAuth scope filtering: <https://github.blog/changelog/2026-01-28-github-mcp-server-new-projects-tools-oauth-scope-filtering-and-new-features/>
- Changelog — tool-specific configuration: <https://github.blog/changelog/2025-12-10-the-github-mcp-server-adds-support-for-tool-specific-configuration-and-more/>
- Feature request — issue relationships (parent / blocked-by): <https://github.com/github/github-mcp-server/issues/950>
- Feature request — Create Milestone: <https://github.com/github/github-mcp-server/issues/258>
- Feature request — ProjectV2 status read/write: <https://github.com/github/github-mcp-server/issues/1963>
- Sub-issue support — issues [#154](https://github.com/github/github-mcp-server/issues/154), [#196](https://github.com/github/github-mcp-server/issues/196)

## Findings

### The decisive architectural fact: no generic API passthrough

`gh api` is an **escape hatch** — it can call *any* REST endpoint or *any* GraphQL query/mutation.
The plugin leans on this heavily: milestones, sub-issues, issue dependencies, `updateProjectV2`,
and `releases/generate-notes` are all reached through `gh api …`, not through a first-class `gh`
subcommand.

The GitHub MCP server has **no equivalent generic passthrough tool**. It exposes a fixed catalogue
of typed tools grouped into toolsets. **If GitHub has not written a tool for an endpoint, that
endpoint is simply unreachable through the MCP server** — there is no `mcp api <path>` fallback.
This single fact dominates the whole evaluation: coverage is bounded by what GitHub has chosen to
implement, with no workaround.

### Coverage matrix

Legend:

- **COVERED** = a dedicated MCP tool exists.
- **PARTIAL** = reachable for some uses but not the way the plugin needs it.
- **MISSING** = no tool; only reachable via `gh api`.

| Plugin `gh` operation | Used by | MCP tool / toolset | Verdict |
|---|---|---|---|
| `gh issue create` | add-item, migrate, add-external-blocker | `create_issue` (issues) | **COVERED** |
| `gh issue edit` (labels, assignee, body) | many | `update_issue` (issues) | **COVERED** |
| `gh issue edit --milestone` | add-item, plan-release | `update_issue` (milestone param) | **COVERED** |
| `gh issue view` | many | `get_issue` (issues) | **COVERED** |
| `gh issue list` | audit, health, refine, release-status | `list_issues` / `search_issues` | **COVERED** |
| `gh issue comment` | refine-item, close-release | `add_issue_comment` (issues) | **COVERED** |
| `gh issue close` | (manual fallbacks) | `update_issue` (state=closed) | **COVERED** |
| `gh label list` | initialize, add-item, audit | `list_label` (labels) | **COVERED** |
| `gh label create` | initialize | `label_write` (labels) | **COVERED** |
| `gh repo view` | preflight | `get_repository` / context | **COVERED** |
| `gh pr create` | execute-item, initialize | `create_pull_request` (pull_requests) | **COVERED** |
| `gh project list` | preflight/initialize | `projects_list` (projects) | **COVERED** |
| `gh project view` | initialize, release-status | `projects_get` (projects) | **COVERED** |
| `gh project item-list` | execute-item, add-item, status, health, audit | `projects_get` / list project items | **COVERED** (read) |
| `gh project item-add` | add-item, migrate | `projects_write` → `add_project_item` | **COVERED** |
| `gh project field-list` | execute-item, add-item | `list_project_fields` / `projects_get` | **COVERED** |
| `gh project item-edit` (set **Status**) | execute-item, add-item, migrate | `projects_write` → `update_project_item` | **PARTIAL** — item-field write exists, but explicit ProjectV2 **status** read/write is still an open request ([#1963](https://github.com/github/github-mcp-server/issues/1963)); needs hands-on confirmation that the single-select Status option can be set |
| `gh project create` | initialize | — | **MISSING** — no create-project tool |
| `gh project link` (Project → repo) | initialize | — | **MISSING** |
| `gh api graphql updateProjectV2` (shortDescription) | initialize | — | **MISSING** — `projects_write` operates on **items**, not project metadata |
| `gh api graphql` **rank / item position** reorder | add-item (rank insertion) | — | **MISSING** — no position/reorder tool; the entire rank-ordering model (CLAUDE.md invariant 6) has no write path |
| `gh api repos/.../milestones` **POST** (create) | plan-release | — | **MISSING** — open request ([#258](https://github.com/github/github-mcp-server/issues/258)) |
| `gh api repos/.../milestones/<n>` **PATCH** state=closed | close-release | — | **MISSING** |
| `gh api repos/.../milestones?state=…` (list/read `due_on`) | execute-item, add-item, status | — | **MISSING** — milestone metadata (esp. `due_on` for active-milestone resolution) has no read tool; `list_issues` filters by milestone but does not return milestone `due_on` |
| `gh api .../sub_issues` POST / DELETE | add-item, migrate, refine-item | `add_sub_issue` / `remove_sub_issue` / `reprioritize_sub_issue` (issues) | **COVERED** |
| `gh api .../issues/<n>/parent` (read parent) | execute-item, add-item | — | **PARTIAL / MISSING** — `get_issue` does not return parent; tracked in [#950](https://github.com/github/github-mcp-server/issues/950) |
| `gh api .../dependencies/blocked_by` (read) | **execute-item block-skipping**, block-item, audit, resolve-external-blocker | — | **MISSING** — [#950](https://github.com/github/github-mcp-server/issues/950) open |
| `gh api .../dependencies/blocking` POST / DELETE | block-item, add-external-blocker, resolve-external-blocker | — | **MISSING** |
| `gh api repos/.../releases/generate-notes` POST | close-release | — | **MISSING** (no release-notes generation tool verified) |
| `gh api user` | preflight | `get_me` (context/users) | **COVERED** |
| `gh auth status` | preflight | n/a — auth is via token/OAuth, not a tool | **N/A** |

### The three explicitly-required investigations

**Issue Dependencies API → MISSING.** This is the headline gap. There is **no** tool to read
`blocked_by`, nor to create/delete `blocking` relationships. The capability is an open feature
request ([#950](https://github.com/github/github-mcp-server/issues/950)). This directly collides
with **CLAUDE.md invariant 7** ("Native deps as source of truth") and is load-bearing for
`execute-backlog-item`'s strict block-skipping, `block-backlog-item`, `add-external-blocker`, and
`resolve-external-blocker`. The plugin literally *cannot* implement block-skipping on MCP today.

**Sub-issues API → COVERED.** `add_sub_issue`, `remove_sub_issue`, and `reprioritize_sub_issue`
exist (issues [#154](https://github.com/github/github-mcp-server/issues/154),
[#196](https://github.com/github/github-mcp-server/issues/196) — now landed). The one soft spot is
**reading** an issue's parent: `get_issue` does not surface it (part of
[#950](https://github.com/github/github-mcp-server/issues/950)). `execute-backlog-item` Step 7.4 and
the migrate re-parenting flow both read `/parent`, so this is a PARTIAL.

**Projects v2 GraphQL → PARTIAL.** GitHub added a consolidated projects toolset
(`projects_list`, `projects_get`, `projects_write` with `add_project_item` / `update_project_item` /
`list_project_fields`). Reads and item-add are well covered. But three things the plugin needs are
**not** exposed: (a) **creating** a Project and **linking** it to a repo (`initialize`),
(b) editing the Project's **shortDescription** (`updateProjectV2`), and (c) **reordering item rank /
position** — the manual Todo-column ordering that CLAUDE.md invariant 6 makes the heart of execution
order. Status-field *writes* are plausibly covered by `update_project_item` but remain unconfirmed
([#1963](https://github.com/github/github-mcp-server/issues/1963)).

### Install UX

**Today (`gh`):**
1. `brew install gh` (or apt/winget/preinstalled in most CI).
2. `gh auth login` — interactive browser/device flow, stores a token in the OS keychain.
3. Done. One tool, ubiquitous in dev environments, no per-project config.

**With the MCP server — two paths:**

*Remote hosted server* (lowest-friction MCP path):
1. Add an `.mcp.json` entry pointing at `https://api.githubcopilot.com/mcp/` (or a per-toolset URL
   such as `…/mcp/x/issues`, with optional `/readonly` suffix).
2. Authenticate via OAuth (in supporting clients) or supply a token.
3. Reload the client so it discovers the toolset.

*Local server* (Docker):
1. Install and run Docker.
2. Create a **GitHub Personal Access Token** with the right scopes.
3. Add an `.mcp.json` entry: `docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN=… ghcr.io/github/github-mcp-server` (optionally `-e GITHUB_READ_ONLY=1`, `-e GITHUB_TOOLSETS=…`).
4. Reload the client.

Net: the MCP path adds a container runtime (or trust in a remote service) and a hand-rolled PAT to
what is currently a single ubiquitous binary. For a plugin meant to be `git clone`-and-go, this is a
**heavier** first-run, not a lighter one.

### Permission UX

This is the one place MCP is genuinely **better** than the status quo.

- **`yolo`-equivalent:** today = `Bash(gh *)` + `Bash(git *)` blanket allow. MCP equivalent = grant the
  server's tools (or the `…/x/all` endpoint). Comparable, and arguably cleaner because it is scoped to
  GitHub tools rather than all of `gh`/shell.
- **`safe`-equivalent:** today the README admits read-only mode is *leaky* — `gh api "repos/..."`
  covers both reads and writes under one prefix, so the allowlist "cannot be cleanly separated by
  pattern" and those calls still prompt. The MCP server solves this cleanly:
  - Local: `--read-only` flag / `GITHUB_READ_ONLY=1` — "a strict security filter that takes
    precedence over any other configuration," disabling all write tools.
  - Remote: append `/readonly` to any toolset URL.
  - Plus `--toolsets` / `GITHUB_TOOLSETS` and tool-specific config (Changelog 2025-12-10) for
    fine-grained, per-tool grants.

  This is a strictly better read-only story than the current leaky `gh api` prefix problem.

So permission UX is the **one** column where MCP wins — but it wins on a problem (leaky `safe` mode)
that is minor relative to the coverage gaps.

### Auth interplay

The local server requires its **own** token: `GITHUB_PERSONAL_ACCESS_TOKEN`. It does **not**
automatically discover or reuse the `gh` CLI's keychain token. You *can* bridge them manually
(e.g. `GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token)`), but that is extra wiring the user must own,
and it means the plugin would still effectively depend on `gh` (or a hand-managed PAT) for auth. The
remote server uses OAuth in supporting clients. Either way, this is **net-new auth friction** versus
today's single `gh auth login`.

### Migration cost (if we did it)

- **Read paths** (issue/project/label reads): ~5 of the heaviest call sites — mechanically swappable.
- **Write paths that are covered** (issue create/update, sub-issues, project item-add, PR create):
  another large chunk — swappable.
- **Write/read paths that are MISSING** and would have to **stay on `gh`** regardless:
  - Issue dependencies (read **and** write) — `execute-item`, `block-item`, both external-blocker skills, `audit`.
  - Milestones create/close/read-`due_on` — `plan-release`, `close-release`, active-milestone resolution in `execute-item`/`add-item`/`release-status`.
  - Project create + link + description — `initialize`.
  - Project rank/position reorder — `add-item`.
  - Release notes generation — `close-release`.

Because dependency **reads** are required for the most-used command (`execute-backlog-item`'s
block-skipping), even a "reads-only" partial migration cannot eliminate the `gh` + Bash dependency.
A partial migration would therefore yield a **hybrid** that still ships `gh`, still needs the Bash
allowlist, **and** adds Docker/PAT/`.mcp.json` setup — strictly more moving parts, for the benefit of
typed tool calls on a subset of operations. That is precisely the "messier than what we have now"
outcome the issue warned about.

## Recommendation

**Stay on `gh`.**

Rationale:

1. **Coverage is disqualifying, not marginal.** The Issue Dependencies API — the spine of this
   plugin's execution model (CLAUDE.md invariant 7) — has no MCP tool at all. Milestone create/close,
   project create/link/description, and project rank reordering are also missing. There is no generic
   `api` passthrough to bridge the gaps, so these are hard blockers, not workarounds-away.
2. **A partial migration makes things worse.** Since dependency reads gate the most-used command, the
   plugin would still ship `gh` and the Bash allowlist, now *plus* a container/PAT/`.mcp.json`. More
   setup, more failure modes, split mental model.
3. **The one real win (clean read-only mode) is small** relative to the cost, and the current leaky
   `safe` mode is a documented, tolerable limitation.
4. **Install UX regresses** from one ubiquitous binary to Docker-or-remote + bespoke PAT.

**Revisit when** the following land (watch these issues):
- Issue Dependencies read+write tools — [#950](https://github.com/github/github-mcp-server/issues/950).
- Milestone create/close tools — [#258](https://github.com/github/github-mcp-server/issues/258).
- ProjectV2 status + rank/position write — [#1963](https://github.com/github/github-mcp-server/issues/1963) and a position/reorder tool.
- Project create / link / metadata tools.

When (if) those exist, re-run this spike: the calculus flips toward at least a partial migration for
the permission-UX and structured-output benefits.

## Follow-on Work

None. The **stay on `gh`** verdict requires no implementation work. The revisit triggers are the
upstream feature requests already linked above ([#950](https://github.com/github/github-mcp-server/issues/950),
[#258](https://github.com/github/github-mcp-server/issues/258),
[#1963](https://github.com/github/github-mcp-server/issues/1963), and a project-create/rank tool);
re-run this spike if and when they land. No backlog items were created per the decision recorded
during sign-off.
