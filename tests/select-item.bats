#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(dirname "$(dirname "$BATS_TEST_FILENAME")")"
  SELECT_ITEM="$REPO_ROOT/bin/select-item"

  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"
  export GH_MOCK_DIR="$(mktemp -d)"
  export PATH="$MOCK_BIN:$PATH"

  cd "$TEST_DIR"

  mkdir -p .claude
  cat > .claude/backlog-project.json << 'JSON'
{
  "owner": "testowner",
  "repo": "testrepo",
  "project_number": 1,
  "project_id": "PVT_test",
  "status_field_id": "PVTF_test",
  "status_options": {
    "Todo": "opt_todo",
    "In Progress": "opt_inprogress",
    "Done": "opt_done"
  }
}
JSON

  # resolve-milestone mock
  cat > "$MOCK_BIN/resolve-milestone" << 'SCRIPT'
#!/usr/bin/env bash
echo '{"number": 8, "title": "v0.6.0", "due_on": "2026-07-14T00:00:00Z"}'
SCRIPT
  chmod +x "$MOCK_BIN/resolve-milestone"

  # gh mock — reads fixtures from $GH_MOCK_DIR at runtime (not expanded here)
  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "api" ]]; then
  path="${1:-}"
  if [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/dependencies/blocked_by$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/blockers_${num}.json"
    if [[ -f "${file}.404" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/sub_issues$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/sub_issues' | grep -oE '[0-9]+')
    cat "$GH_MOCK_DIR/sub_issues_${num}.json"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/parent$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/parent' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/parent_${num}.json"
    if [[ ! -f "$file" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+$' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/issue_${num}.json"
    if [[ -f "${file}.404" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  else
    echo "Unhandled api path: $path" >&2; exit 1
  fi

elif [[ "$subcmd" == "project" ]]; then
  subcmd2="${1:-}"
  shift || true
  if [[ "$subcmd2" == "item-list" ]]; then
    args="$*"
    if echo "$args" | grep -qF "In Progress"; then
      cat "$GH_MOCK_DIR/items_inprogress.json"
    elif echo "$args" | grep -qF "no:milestone"; then
      if echo "$args" | grep -qF -- "-label:"; then
        jq '.items = [.items[] | select((.labels // [] | index("type:external-blocker")) == null)]' \
          "$GH_MOCK_DIR/items_tier2.json"
      else
        cat "$GH_MOCK_DIR/items_tier2.json"
      fi
    else
      if echo "$args" | grep -qF -- "-label:"; then
        jq '.items = [.items[] | select((.labels // [] | index("type:external-blocker")) == null)]' \
          "$GH_MOCK_DIR/items_tier1.json"
      else
        cat "$GH_MOCK_DIR/items_tier1.json"
      fi
    fi
  else
    echo "Unhandled project subcmd: $subcmd2" >&2; exit 1
  fi

else
  echo "Unhandled gh subcmd: $subcmd ($*)" >&2; exit 1
fi
SCRIPT
  chmod +x "$MOCK_BIN/gh"

  # Default fixtures shared across tests
  echo '{"items": []}' > "$GH_MOCK_DIR/items_inprogress.json"
  echo '{"items": []}' > "$GH_MOCK_DIR/items_tier1.json"
  echo '{"items": []}' > "$GH_MOCK_DIR/items_tier2.json"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$GH_MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

issue_item() {
  local num="$1" title="$2" milestone="${3:-v0.6.0}"
  local ms_json
  [[ -n "$milestone" ]] && ms_json="{\"title\": \"$milestone\"}" || ms_json="null"
  printf '{
    "id": "PVTI_%s", "type": null,
    "content": {
      "number": %s, "title": "%s",
      "body": "Issue body.",
      "url": "https://github.com/testowner/testrepo/issues/%s"
    },
    "labels": ["type:feature", "priority:P1", "effort:S"],
    "milestone": %s,
    "status": "Todo", "linked pull requests": []
  }' "$num" "$num" "$title" "$num" "$ms_json"
}

no_blockers_summary() {
  local num="$1" title="$2"
  printf '{"number": %s, "title": "%s", "state": "open", "issue_dependencies_summary": {"blocked_by": 0}}' \
    "$num" "$title"
}

# ---------------------------------------------------------------------------
# AC1 — script exists and is executable
# ---------------------------------------------------------------------------

@test "AC1: bin/select-item exists and is executable" {
  [[ -x "$SELECT_ITEM" ]]
}

# ---------------------------------------------------------------------------
# AC7 — in_progress is empty array when no items in flight
# ---------------------------------------------------------------------------

@test "AC7a: in_progress is empty array when current user has no In Progress items" {
  # Default fixtures: empty items_inprogress.json
  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]
  result=$(echo "$output" | jq -c '.in_progress')
  [[ "$result" == "[]" ]]
}

# ---------------------------------------------------------------------------
# AC2 — returns winner JSON for unblocked Todo item
# ---------------------------------------------------------------------------

@test "AC2: returns winner candidate for unblocked Tier 1 Todo item" {
  printf '{"items": [%s]}' "$(issue_item 42 'Do something')" \
    > "$GH_MOCK_DIR/items_tier1.json"

  no_blockers_summary 42 "Do something" > "$GH_MOCK_DIR/issue_42.json"
  echo '[]' > "$GH_MOCK_DIR/sub_issues_42.json"
  # No parent file → 404

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "42" ]]

  milestone_title=$(echo "$output" | jq -r '.active_milestone.title')
  [[ "$milestone_title" == "v0.6.0" ]]

  candidate_tier=$(echo "$output" | jq -r '.candidate.tier')
  [[ "$candidate_tier" == "1" ]]

  message=$(echo "$output" | jq -r '.message')
  [[ "$message" == "null" ]]
}

@test "AC2b: falls back to Tier 2 (no-milestone) when Tier 1 is empty" {
  printf '{"items": [%s]}' "$(issue_item 99 'No-milestone item' '')" \
    > "$GH_MOCK_DIR/items_tier2.json"
  # Override: strip milestone from content
  cat > "$GH_MOCK_DIR/items_tier2.json" << 'JSON'
{"items": [{"id": "PVTI_99", "type": null, "content": {"number": 99, "title": "No-milestone item", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/99"}, "labels": ["type:feature", "priority:P2", "effort:S"], "milestone": null, "status": "Todo", "linked pull requests": []}]}
JSON

  no_blockers_summary 99 "No-milestone item" > "$GH_MOCK_DIR/issue_99.json"
  echo '[]' > "$GH_MOCK_DIR/sub_issues_99.json"

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "99" ]]

  candidate_tier=$(echo "$output" | jq -r '.candidate.tier')
  [[ "$candidate_tier" == "2" ]]
}

# ---------------------------------------------------------------------------
# AC4 — candidate null when no actionable items
# ---------------------------------------------------------------------------

@test "AC4a: candidate is null with message when no items exist" {
  # Default fixtures: all empty
  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate=$(echo "$output" | jq -r '.candidate')
  [[ "$candidate" == "null" ]]

  message=$(echo "$output" | jq -r '.message')
  [[ -n "$message" && "$message" != "null" ]]
}

@test "AC4b: candidate is null with message when all items are blocked" {
  printf '{"items": [%s]}' "$(issue_item 10 'Blocked item')" \
    > "$GH_MOCK_DIR/items_tier1.json"

  cat > "$GH_MOCK_DIR/issue_10.json" << 'JSON'
{"number": 10, "title": "Blocked item", "state": "open", "issue_dependencies_summary": {"blocked_by": 1}}
JSON
  cat > "$GH_MOCK_DIR/blockers_10.json" << 'JSON'
[{"number": 77, "title": "Open blocker", "html_url": "https://github.com/testowner/testrepo/issues/77", "state": "open", "labels": [{"name": "type:feature"}], "assignees": []}]
JSON

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate=$(echo "$output" | jq -r '.candidate')
  [[ "$candidate" == "null" ]]

  message=$(echo "$output" | jq -r '.message')
  [[ -n "$message" && "$message" != "null" ]]

  skipped_num=$(echo "$output" | jq -r '.skipped_blocked[0].number')
  [[ "$skipped_num" == "10" ]]
}

# ---------------------------------------------------------------------------
# AC3 — skips blocked items, populates skipped_blocked
# ---------------------------------------------------------------------------

@test "AC3: skips blocked items and picks the first unblocked candidate" {
  printf '{"items": [%s, %s]}' \
    "$(issue_item 10 'Blocked item')" \
    "$(issue_item 20 'Unblocked item')" \
    > "$GH_MOCK_DIR/items_tier1.json"

  cat > "$GH_MOCK_DIR/issue_10.json" << 'JSON'
{"number": 10, "title": "Blocked item", "state": "open", "issue_dependencies_summary": {"blocked_by": 1}}
JSON
  cat > "$GH_MOCK_DIR/blockers_10.json" << 'JSON'
[{"number": 77, "title": "Open blocker", "html_url": "https://github.com/testowner/testrepo/issues/77", "state": "open", "labels": [{"name": "type:external-blocker"}], "assignees": []}]
JSON

  no_blockers_summary 20 "Unblocked item" > "$GH_MOCK_DIR/issue_20.json"
  echo '[]' > "$GH_MOCK_DIR/sub_issues_20.json"

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "20" ]]

  skipped_num=$(echo "$output" | jq -r '.skipped_blocked[0].number')
  [[ "$skipped_num" == "10" ]]

  blocker_num=$(echo "$output" | jq -r '.skipped_blocked[0].open_blockers[0].number')
  [[ "$blocker_num" == "77" ]]

  blocker_url=$(echo "$output" | jq -r '.skipped_blocked[0].open_blockers[0].url')
  [[ "$blocker_url" == "https://github.com/testowner/testrepo/issues/77" ]]

  blocker_labels=$(echo "$output" | jq -c '.skipped_blocked[0].open_blockers[0].labels')
  [[ "$blocker_labels" == '["type:external-blocker"]' ]]

  cross_repo=$(echo "$output" | jq -r '.skipped_blocked[0].open_blockers[0].cross_repo')
  [[ "$cross_repo" == "false" ]]
}

# ---------------------------------------------------------------------------
# AC5 — 404 on dependencies API: all unblocked + warning
# ---------------------------------------------------------------------------

@test "AC5: 404 on dependencies API treats all items as unblocked and adds warning" {
  printf '{"items": [%s]}' "$(issue_item 42 'Do something')" \
    > "$GH_MOCK_DIR/items_tier1.json"

  # Mark the issue summary as having 1 blocker, but the blockers endpoint returns 404
  cat > "$GH_MOCK_DIR/issue_42.json" << 'JSON'
{"number": 42, "title": "Do something", "state": "open", "issue_dependencies_summary": {"blocked_by": 1}}
JSON
  touch "$GH_MOCK_DIR/blockers_42.json.404"

  echo '[]' > "$GH_MOCK_DIR/sub_issues_42.json"

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "42" ]]

  warning=$(echo "$output" | jq -r '.warnings[0]')
  [[ "$warning" == *"unavailable"* ]]
}

# ---------------------------------------------------------------------------
# AC6 — sub-issue case: parent skipped, sub-issue becomes candidate
# ---------------------------------------------------------------------------

@test "AC6: parent with open Todo sub-issues is skipped; sub-issue becomes candidate" {
  # Tier 1: parent #100 first, then sub-issue #101
  cat > "$GH_MOCK_DIR/items_tier1.json" << 'JSON'
{"items": [
  {"id": "PVTI_100", "type": null, "content": {"number": 100, "title": "Parent item", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/100"}, "labels": ["type:feature", "priority:P1", "effort:L"], "milestone": {"title": "v0.6.0"}, "status": "Todo", "linked pull requests": []},
  {"id": "PVTI_101", "type": null, "content": {"number": 101, "title": "Sub-issue item", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/101"}, "labels": ["type:feature", "priority:P1", "effort:S"], "milestone": {"title": "v0.6.0"}, "status": "Todo", "linked pull requests": []}
]}
JSON

  no_blockers_summary 100 "Parent item" > "$GH_MOCK_DIR/issue_100.json"

  # Parent #100 has open sub-issue #101 in the project
  cat > "$GH_MOCK_DIR/sub_issues_100.json" << 'JSON'
[{"number": 101, "title": "Sub-issue item", "state": "open"}]
JSON

  no_blockers_summary 101 "Sub-issue item" > "$GH_MOCK_DIR/issue_101.json"
  echo '[]' > "$GH_MOCK_DIR/sub_issues_101.json"

  # Sub-issue #101's parent is #100
  cat > "$GH_MOCK_DIR/parent_101.json" << 'JSON'
{"number": 100, "title": "Parent item", "body": "### What\nBig thing\n\n### Why\nBecause", "html_url": "https://github.com/testowner/testrepo/issues/100"}
JSON

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "101" ]]

  skipped_parent=$(echo "$output" | jq -r '.skipped_for_sub_issues[0].number')
  [[ "$skipped_parent" == "100" ]]

  parent_num=$(echo "$output" | jq -r '.candidate.parent.number')
  [[ "$parent_num" == "100" ]]
}

# ---------------------------------------------------------------------------
# AC7b — in_progress populated when current user has items in flight
# ---------------------------------------------------------------------------

@test "AC7b: in_progress populated with current user's In Progress items" {
  # Fixture reflects server-side assignee:@me filtering — only current user's items
  cat > "$GH_MOCK_DIR/items_inprogress.json" << 'JSON'
{"items": [
  {"id": "PVTI_55", "type": null, "content": {"number": 55, "title": "WIP item", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/55"}, "labels": ["type:feature", "priority:P1", "effort:M"], "milestone": {"title": "v0.6.0"}, "status": "In Progress", "linked pull requests": ["https://github.com/testowner/testrepo/pull/88"]}
]}
JSON

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  count=$(echo "$output" | jq '.in_progress | length')
  [[ "$count" == "1" ]]

  num=$(echo "$output" | jq -r '.in_progress[0].number')
  [[ "$num" == "55" ]]

  linked_pr=$(echo "$output" | jq -r '.in_progress[0].linked_pr.number')
  [[ "$linked_pr" == "88" ]]

  milestone=$(echo "$output" | jq -r '.in_progress[0].milestone')
  [[ "$milestone" == "v0.6.0" ]]
}

# ---------------------------------------------------------------------------
# AC1b — exit non-zero on infrastructure failure (missing metadata file)
# ---------------------------------------------------------------------------

@test "AC1b: exits non-zero when .claude/backlog-project.json is missing" {
  rm .claude/backlog-project.json
  run "$SELECT_ITEM"
  [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# AC3b — type:external-blocker items are never picked as candidates
# ---------------------------------------------------------------------------

@test "AC3b: items with type:external-blocker are never selected as candidates" {
  cat > "$GH_MOCK_DIR/items_tier1.json" << 'JSON'
{"items": [
  {"id": "PVTI_77", "type": null, "content": {"number": 77, "title": "External blocker stub", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/77"}, "labels": ["type:external-blocker"], "milestone": {"title": "v0.6.0"}, "status": "Todo", "linked pull requests": []}
]}
JSON

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  candidate=$(echo "$output" | jq -r '.candidate')
  [[ "$candidate" == "null" ]]
}

# ---------------------------------------------------------------------------
# sub_issues_summary included in candidate
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# #189 — resolve-milestone exit 2 (no open milestones) falls through to a
# milestone-less run instead of exiting fatally.
# ---------------------------------------------------------------------------

@test "#189: falls back to Tier 2 with active_milestone null when resolve-milestone exits 2" {
  cat > "$MOCK_BIN/resolve-milestone" << 'SCRIPT'
#!/usr/bin/env bash
echo "No open milestones found." >&2
exit 2
SCRIPT
  chmod +x "$MOCK_BIN/resolve-milestone"

  # Tier 1 must never be queried in this fallback — error out if it is, to
  # prove pick-item skips that call path entirely.
  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "api" ]]; then
  path="${1:-}"
  if [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/dependencies/blocked_by$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/blockers_${num}.json"
    if [[ -f "${file}.404" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/sub_issues$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/sub_issues' | grep -oE '[0-9]+')
    cat "$GH_MOCK_DIR/sub_issues_${num}.json"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+/parent$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+/parent' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/parent_${num}.json"
    if [[ ! -f "$file" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  elif [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
    num=$(echo "$path" | grep -oE '/issues/[0-9]+$' | grep -oE '[0-9]+')
    file="$GH_MOCK_DIR/issue_${num}.json"
    if [[ -f "${file}.404" ]]; then
      echo "HTTP 404: Not Found" >&2; exit 1
    fi
    cat "$file"
  else
    echo "Unhandled api path: $path" >&2; exit 1
  fi

elif [[ "$subcmd" == "project" ]]; then
  subcmd2="${1:-}"
  shift || true
  if [[ "$subcmd2" == "item-list" ]]; then
    args="$*"
    if echo "$args" | grep -qF "In Progress"; then
      cat "$GH_MOCK_DIR/items_inprogress.json"
    elif echo "$args" | grep -qF "no:milestone"; then
      cat "$GH_MOCK_DIR/items_tier2.json"
    elif echo "$args" | grep -qF "milestone:"; then
      echo "FATAL: Tier 1 (milestone-scoped) query must not run when there is no Active Release" >&2
      exit 1
    else
      echo "Unhandled item-list args: $args" >&2
      exit 1
    fi
  else
    echo "Unhandled project subcmd: $subcmd2" >&2; exit 1
  fi
else
  echo "Unhandled gh subcmd: $subcmd ($*)" >&2; exit 1
fi
SCRIPT
  chmod +x "$MOCK_BIN/gh"

  cat > "$GH_MOCK_DIR/items_tier2.json" << 'JSON'
{"items": [{"id": "PVTI_99", "type": null, "content": {"number": 99, "title": "No-milestone item", "body": "Issue body.", "url": "https://github.com/testowner/testrepo/issues/99"}, "labels": ["type:feature", "priority:P2", "effort:S"], "milestone": null, "status": "Todo", "linked pull requests": []}]}
JSON

  no_blockers_summary 99 "No-milestone item" > "$GH_MOCK_DIR/issue_99.json"
  echo '[]' > "$GH_MOCK_DIR/sub_issues_99.json"

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  active_milestone=$(echo "$output" | jq -r '.active_milestone')
  [[ "$active_milestone" == "null" ]]

  candidate_num=$(echo "$output" | jq -r '.candidate.number')
  [[ "$candidate_num" == "99" ]]

  candidate_tier=$(echo "$output" | jq -r '.candidate.tier')
  [[ "$candidate_tier" == "2" ]]
}

@test "#189: still exits fatally for other resolve-milestone failures (missing metadata)" {
  cat > "$MOCK_BIN/resolve-milestone" << 'SCRIPT'
#!/usr/bin/env bash
echo "No .claude/backlog-project.json found. Run /initialize first." >&2
exit 1
SCRIPT
  chmod +x "$MOCK_BIN/resolve-milestone"

  run "$SELECT_ITEM"
  [[ "$status" -ne 0 ]]
  [[ "$status" -ne 2 ]]
}

@test "candidate includes sub_issues_summary with total and completed counts" {
  printf '{"items": [%s]}' "$(issue_item 42 'Parent with sub-issues done')" \
    > "$GH_MOCK_DIR/items_tier1.json"

  no_blockers_summary 42 "Parent with sub-issues done" > "$GH_MOCK_DIR/issue_42.json"

  cat > "$GH_MOCK_DIR/sub_issues_42.json" << 'JSON'
[
  {"number": 43, "title": "Sub 1", "state": "closed"},
  {"number": 44, "title": "Sub 2", "state": "closed"}
]
JSON

  run "$SELECT_ITEM"
  [[ "$status" -eq 0 ]]

  total=$(echo "$output" | jq -r '.candidate.sub_issues_summary.total')
  completed=$(echo "$output" | jq -r '.candidate.sub_issues_summary.completed')
  [[ "$total" == "2" ]]
  [[ "$completed" == "2" ]]
}
