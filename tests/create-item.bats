#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(dirname "$(dirname "$BATS_TEST_FILENAME")")"
  CREATE_ITEM="$REPO_ROOT/bin/create-item"

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

  echo "Issue body content." > "$GH_MOCK_DIR/body.txt"

  # gh mock — reads control flags from $GH_MOCK_DIR at runtime
  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "issue" ]]; then
  subcmd2="${1:-}"; shift || true
  if [[ "$subcmd2" == "create" ]]; then
    [[ -f "$GH_MOCK_DIR/issue_create_fail" ]] && { echo "gh issue create: simulated failure" >&2; exit 1; }
    echo "https://github.com/testowner/testrepo/issues/42"
    exit 0
  elif [[ "$subcmd2" == "edit" ]]; then
    [[ -f "$GH_MOCK_DIR/milestone_fail" ]] && { echo "gh issue edit: simulated failure" >&2; exit 1; }
    exit 0
  fi

elif [[ "$subcmd" == "project" ]]; then
  subcmd2="${1:-}"; shift || true
  if [[ "$subcmd2" == "item-add" ]]; then
    [[ -f "$GH_MOCK_DIR/item_add_fail" ]] && { echo "gh project item-add: simulated failure" >&2; exit 1; }
    echo '{"id": "PVTI_42", "type": "ISSUE", "content": {"number": 42, "url": "https://github.com/testowner/testrepo/issues/42"}}'
    exit 0
  elif [[ "$subcmd2" == "item-edit" ]]; then
    [[ -f "$GH_MOCK_DIR/item_edit_fail" ]] && { echo "gh project item-edit: simulated failure" >&2; exit 1; }
    echo '{"id": "PVTI_42"}'
    exit 0
  elif [[ "$subcmd2" == "item-list" ]]; then
    cat "$GH_MOCK_DIR/items_todo.json" 2>/dev/null || echo '{"items": []}'
    exit 0
  fi

elif [[ "$subcmd" == "api" ]]; then
  method="GET"
  path=""
  jq_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -X|--method) method="$2"; shift 2;;
      -f|--field) shift 2;;
      --jq) jq_filter="$2"; shift 2;;
      -*) shift;;
      *) [[ -z "$path" ]] && path="$1"; shift;;
    esac
  done

  if [[ "$path" == "graphql" ]]; then
    [[ -f "$GH_MOCK_DIR/graphql_fail" ]] && { echo "GraphQL: simulated failure" >&2; exit 1; }
    echo '{"data": {"updateProjectV2ItemPosition": {"items": {"totalCount": 5}}}}'
    exit 0
  fi

  if [[ "$method" == "POST" ]]; then
    if [[ "$path" =~ /dependencies/blocked_by ]]; then
      if [[ -f "$GH_MOCK_DIR/deps_404" ]]; then
        echo "HTTP 404: Not Found" >&2; exit 1
      fi
      echo '{"id": 1}'; exit 0
    fi
    if [[ "$path" =~ /dependencies/blocking ]]; then
      if [[ -f "$GH_MOCK_DIR/deps_404" ]]; then
        echo "HTTP 404: Not Found" >&2; exit 1
      fi
      echo '{"id": 1}'; exit 0
    fi
    if [[ "$path" =~ /sub_issues ]]; then
      [[ -f "$GH_MOCK_DIR/parent_fail" ]] && { echo "sub_issues: simulated failure" >&2; exit 1; }
      echo '{"id": 1}'; exit 0
    fi
  fi

  # GET issue by number — used for ID resolution
  if [[ "$path" =~ ^repos/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
    num=$(echo "$path" | grep -oE '[0-9]+$')
    result="{\"id\": 100${num}, \"number\": ${num}, \"state\": \"open\"}"
    if [[ -n "$jq_filter" ]]; then
      echo "$result" | jq -r "$jq_filter"
    else
      echo "$result"
    fi
    exit 0
  fi

  echo "Unhandled api: method=$method path=$path" >&2; exit 1
fi

echo "Unhandled gh: $subcmd $*" >&2
exit 1
SCRIPT
  chmod +x "$MOCK_BIN/gh"

  echo '{"items": []}' > "$GH_MOCK_DIR/items_todo.json"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$GH_MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

write_manifest() {
  local file="$1"
  shift
  echo "$@" > "$file"
}

default_manifest() {
  local file="$1"
  cat > "$file" << JSON
{
  "title": "Test issue title",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:feature", "priority:P2", "effort:S"]
}
JSON
}

# ---------------------------------------------------------------------------
# AC1 — --help (or no args) prints usage and exits 0
# ---------------------------------------------------------------------------

@test "AC1a: no args prints usage and exits 0" {
  run "$CREATE_ITEM"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "AC1b: --help prints usage and exits 0" {
  run "$CREATE_ITEM" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ---------------------------------------------------------------------------
# AC2 — Success path: valid manifest emits correct JSON blob
# ---------------------------------------------------------------------------

@test "AC2: success path emits full JSON blob with all required fields" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  default_manifest "$manifest"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  issue_num=$(echo "$output" | jq -r '.issue.number')
  [[ "$issue_num" == "42" ]]

  issue_url=$(echo "$output" | jq -r '.issue.url')
  [[ "$issue_url" == "https://github.com/testowner/testrepo/issues/42" ]]

  labels=$(echo "$output" | jq -c '.labels')
  [[ "$labels" == '["type:feature","priority:P2","effort:S"]' ]]

  status=$(echo "$output" | jq -r '.status')
  [[ "$status" == "Todo" ]]

  rank_applied=$(echo "$output" | jq -r '.rank.applied')
  [[ "$rank_applied" == "false" ]]

  milestone=$(echo "$output" | jq -r '.milestone')
  [[ "$milestone" == "null" ]]

  warnings=$(echo "$output" | jq -c '.warnings')
  [[ "$warnings" == "[]" ]]

  # All required keys present (use has() to handle null values)
  echo "$output" | jq -e 'has("rank_adjustments_applied")' > /dev/null
  echo "$output" | jq -e 'has("blocked_by")' > /dev/null
  echo "$output" | jq -e 'has("blocking")' > /dev/null
  echo "$output" | jq -e 'has("parent")' > /dev/null
}

@test "AC2b: success path with rank top emits rank.applied=true" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  cat > "$manifest" << JSON
{
  "title": "Ranked issue",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:performance", "priority:P1", "effort:M"],
  "rank": {"position": "top"}
}
JSON

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  rank_applied=$(echo "$output" | jq -r '.rank.applied')
  [[ "$rank_applied" == "true" ]]

  warnings=$(echo "$output" | jq -c '.warnings')
  [[ "$warnings" == "[]" ]]
}

@test "AC2c: success path with milestone sets milestone in output" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  cat > "$manifest" << JSON
{
  "title": "Milestoned issue",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:feature", "priority:P2", "effort:S"],
  "milestone": "v0.6.0"
}
JSON

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  milestone=$(echo "$output" | jq -r '.milestone')
  [[ "$milestone" == "v0.6.0" ]]
}

# ---------------------------------------------------------------------------
# AC3 — Fatal: gh issue create fails → exit non-zero, error on stderr
# ---------------------------------------------------------------------------

@test "AC3: gh issue create failure exits non-zero with error on stderr, no stdout blob" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  default_manifest "$manifest"
  touch "$GH_MOCK_DIR/issue_create_fail"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -ne 0 ]]
  # stderr should contain error (bats captures it in $output when combined)
  # Using run's combined output check
  [[ "$output" == *"simulated failure"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"fail"* ]]
}

# ---------------------------------------------------------------------------
# AC4 — Fatal: gh project item-add fails → exit non-zero
# ---------------------------------------------------------------------------

@test "AC4: gh project item-add failure exits non-zero" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  default_manifest "$manifest"
  touch "$GH_MOCK_DIR/item_add_fail"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# AC5 — Non-fatal: rank GraphQL mutation fails → warning in blob, exit 0
# ---------------------------------------------------------------------------

@test "AC5: GraphQL rank mutation failure adds warning but exits 0" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  cat > "$manifest" << JSON
{
  "title": "Ranked issue",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:feature", "priority:P1", "effort:M"],
  "rank": {"position": "top"}
}
JSON
  touch "$GH_MOCK_DIR/graphql_fail"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  rank_applied=$(echo "$output" | jq -r '.rank.applied')
  [[ "$rank_applied" == "false" ]]

  warnings_len=$(echo "$output" | jq '.warnings | length')
  [[ "$warnings_len" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# AC6 — Non-fatal: gh issue edit --milestone fails → warning in blob, exit 0
# ---------------------------------------------------------------------------

@test "AC6: milestone assignment failure adds warning but exits 0" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  cat > "$manifest" << JSON
{
  "title": "Milestoned issue",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:feature", "priority:P2", "effort:S"],
  "milestone": "v0.6.0"
}
JSON
  touch "$GH_MOCK_DIR/milestone_fail"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  milestone=$(echo "$output" | jq -r '.milestone')
  [[ "$milestone" == "null" ]]

  warnings_len=$(echo "$output" | jq '.warnings | length')
  [[ "$warnings_len" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# AC7 — Non-fatal: Dependencies API 404 → warning in blob, exit 0
# ---------------------------------------------------------------------------

@test "AC7: Dependencies API 404 adds warning but exits 0" {
  local manifest="$GH_MOCK_DIR/manifest.json"
  cat > "$manifest" << JSON
{
  "title": "Blocked issue",
  "body_file": "$GH_MOCK_DIR/body.txt",
  "labels": ["type:feature", "priority:P2", "effort:S"],
  "blocked_by": [{"owner": "testowner", "repo": "testrepo", "number": 10}]
}
JSON
  touch "$GH_MOCK_DIR/deps_404"

  run "$CREATE_ITEM" --input "$manifest"
  [[ "$status" -eq 0 ]]

  warnings_len=$(echo "$output" | jq '.warnings | length')
  [[ "$warnings_len" -gt 0 ]]
}
