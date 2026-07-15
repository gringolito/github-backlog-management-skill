---
name: execute-item
description: Pick and execute the topmost unblocked Workable Item from the Queue.
---

## ⚠️ Deprecated

This skill is kept only for backward compatibility and will be removed in an
upcoming release. Use `/pick-item` to select, validate, and assign the next
Workable Item.

# execute-item

You are an AI agent acting as a development lead. Execute the Workable Item selected and assigned by `/pick-item` through to a PR.

## Workflow

### 1. Item Selection (MANDATORY)

Invoke `/pick-item` to select, validate, plan, and assign the next Workable Item. `pick-item` owns preflight, item selection, sub-issue/scope checks, INVEST validation, planning approval, self-assignment, the Project Status update to `In Progress`, and the resume-in-progress guard — `execute-item` does not duplicate any of that.

Take `pick-item`'s resulting candidate and approved plan forward into the steps below.

`pick-item` handles spikes end-to-end through PR creation on its own, so by the time control reaches this skill the item is guaranteed non-spike.

If `pick-item` stops for any reason (INVEST failure, all candidates blocked, epic gate, sub-issue split, Scope Completeness Review, etc.), STOP here too — do not attempt to route around it.

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

#### For Bugs

- Use TDD and write/update tests to reproduce the issue
- Ensure tests FAIL before fixing
- Implement the fix
- Ensure tests PASS after fix

#### For Features / Others

- Implement what was described following the existing project patterns
- Add new tests that validate Acceptance Criteria

### 4. Validation

- Verify ALL Acceptance Criteria are satisfied
- Run full test suite
- Ensure no regressions

### 5. Delivery Workflow

- Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body.
- Push the branch.
- Open a Pull Request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one (omit for un-milestoned items). PR body MUST include:
  - `Closes #<issue-number>` (so GitHub auto-links and auto-closes the issue on merge)
  - A summary of changes mapped to each Acceptance Criterion

### 6. Status & Closure (POST-PR)

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

## Rules & Constraints

- Do NOT exceed defined Scope
- Do NOT ignore Acceptance Criteria
- Do NOT make assumptions -> ask questions
- Keep changes minimal and focused
- Do NOT close the issue manually, always rely on `Closes #N` in the PR
