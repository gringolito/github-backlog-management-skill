---
name: execute-item
description: Pick and execute the topmost unblocked Workable Item from the Queue.
---

## Deprecated

This skill is kept only for backward compatibility and will be removed in an upcoming release. Use `/pick-item` to select, validate, and assign the next Workable Item.

# execute-item

You are an AI agent acting as a development lead. Execute the Workable Item selected and assigned by `/pick-item` through to a PR.

## Workflow

### 1. Item selection

Invoke `/pick-item` to select, validate, plan, and assign the next Workable Item. Use the candidate and approved plan from `pick-item` in the steps below.

If `pick-item` stops for any reason (INVEST failure, all candidates blocked, epic gate, sub-issue split, Scope Completeness Review, etc.), stop here too. Do not work around it.

### 2. Branching

Determine the Conventional Commits prefix from the issue's `type:*` label:

- `type:bug` → `fix/`
- `type:feature` → `feat/`
- `type:performance` → `perf/`
- `type:tech-debt` → `refactor/`
- `type:dx` → `chore/`
- `type:security`, `type:reliability`, `type:compliance` → `fix/` (security/correctness scope)
- Any other custom `type:*` label → use the label value as the prefix (e.g. `type:data-pipeline` → `data-pipeline/`); if the value contains `:`, strip it

Branch name format: `<prefix>/<slug>` (e.g. `fix/null-pointer-in-authn`).

### 3. Implementation

#### For bugs

- Use TDD and write/update tests to reproduce the issue
- Ensure tests FAIL before fixing
- Implement the fix
- Ensure tests PASS after fix

#### For features and others

- Implement what was described following the existing project patterns
- Add new tests that validate Acceptance Criteria

### 4. Validation

- Verify ALL Acceptance Criteria are satisfied
- Run full test suite
- Ensure no regressions

### 5. Delivery workflow

- Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body.
- Push the branch.
- Open a Pull Request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one (omit for un-milestoned items). PR body MUST include:
  - `Closes #<issue-number>` (so GitHub auto-links and auto-closes the issue on merge)
  - A summary of changes mapped to each Acceptance Criterion

### 6. Status and closure (post-PR)

GitHub handles the rest automatically:

- Issue closes when the PR is merged (via `Closes #N`)
- The Project's default workflow flips Status from `In Progress` to `Done` when the issue closes
- The merged PR appears as an automatic timeline link on the issue

If the Project's `Issue closed → Status: Done` workflow is disabled, manually update Status:

- `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <done-option-id>`

### 7. Output

Print:

- Issue URL and number
- PR URL and number
- Branch name
- Assignee (the authenticated user, assigned by `pick-item`)
- Final Project Status (typically `In Progress` until PR merges)

## Rules and constraints

- Do NOT exceed defined Scope
- Do NOT ignore Acceptance Criteria
- Do NOT make assumptions -> ask questions
- Keep changes minimal and focused
- Do NOT close the issue manually, always rely on `Closes #N` in the PR
