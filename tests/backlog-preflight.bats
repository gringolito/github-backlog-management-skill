#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(dirname "$(dirname "$BATS_TEST_FILENAME")")"
  BACKLOG_PREFLIGHT="$REPO_ROOT/bin/backlog-preflight"

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

  # All canonical labels — served for any gh label list call
  cat > "$GH_MOCK_DIR/labels.json" << 'JSON'
[
  {"name": "type:feature"}, {"name": "type:bug"}, {"name": "type:security"},
  {"name": "type:performance"}, {"name": "type:dx"}, {"name": "type:tech-debt"},
  {"name": "type:reliability"}, {"name": "type:compliance"}, {"name": "type:spike"},
  {"name": "type:external-blocker"},
  {"name": "priority:P0"}, {"name": "priority:P1"}, {"name": "priority:P2"}, {"name": "priority:P3"},
  {"name": "effort:XS"}, {"name": "effort:S"}, {"name": "effort:M"}, {"name": "effort:L"}, {"name": "effort:XL"},
  {"name": "needs-clarification"}
]
JSON

  # Default project view response — ID matches metadata
  cat > "$GH_MOCK_DIR/project_view.json" << 'JSON'
{"id": "PVT_test"}
JSON

  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "auth" ]]; then
  [[ -f "$GH_MOCK_DIR/auth_fail" ]] && exit 1
  exit 0

elif [[ "$subcmd" == "repo" ]]; then
  [[ -f "$GH_MOCK_DIR/repo_fail" ]] && { echo "could not determine repo" >&2; exit 1; }
  echo '{"nameWithOwner":"testowner/testrepo"}'
  exit 0

elif [[ "$subcmd" == "project" ]]; then
  subcmd2="${1:-}"; shift || true
  if [[ "$subcmd2" == "view" ]]; then
    [[ -f "$GH_MOCK_DIR/project_not_found" ]] && exit 1
    cat "$GH_MOCK_DIR/project_view.json"
    exit 0
  fi
  echo "Unhandled project subcmd: $subcmd2" >&2; exit 1

elif [[ "$subcmd" == "label" ]]; then
  # Serve the same fixture regardless of --search arg
  cat "$GH_MOCK_DIR/labels.json"
  [[ -f "$GH_MOCK_DIR/label_fail" ]] && exit 1
  exit 0

else
  echo "Unhandled gh subcmd: $subcmd ($*)" >&2; exit 1
fi
SCRIPT
  chmod +x "$MOCK_BIN/gh"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$GH_MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

@test "happy path: exits 0 and emits metadata JSON to stdout" {
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -eq 0 ]]
  owner=$(echo "$output" | jq -r '.owner')
  [[ "$owner" == "testowner" ]]
  project_id=$(echo "$output" | jq -r '.project_id')
  [[ "$project_id" == "PVT_test" ]]
}

# ---------------------------------------------------------------------------
# Auth failure
# ---------------------------------------------------------------------------

@test "auth failure: exits 1 with message on stderr" {
  touch "$GH_MOCK_DIR/auth_fail"
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"gh auth login"* ]]
}

# ---------------------------------------------------------------------------
# Repo view failure
# ---------------------------------------------------------------------------

@test "repo view failure: exits 1 with message on stderr" {
  touch "$GH_MOCK_DIR/repo_fail"
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Cannot determine repo"* ]]
}

# ---------------------------------------------------------------------------
# Missing metadata file
# ---------------------------------------------------------------------------

@test "missing metadata file: exits 1 with message on stderr" {
  rm .claude/backlog-project.json
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Run /initialize first"* ]]
}

# ---------------------------------------------------------------------------
# Schema validation — missing top-level key
# ---------------------------------------------------------------------------

@test "missing top-level key: exits 1 naming the missing key on stderr" {
  cat > .claude/backlog-project.json << 'JSON'
{
  "owner": "testowner",
  "repo": "testrepo",
  "project_number": 1,
  "status_field_id": "PVTF_test",
  "status_options": {
    "Todo": "opt_todo",
    "In Progress": "opt_inprogress",
    "Done": "opt_done"
  }
}
JSON
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"project_id"* ]]
}

# ---------------------------------------------------------------------------
# Schema validation — missing status_options subkey
# ---------------------------------------------------------------------------

@test "missing status_options.Done: exits 1 naming the missing subkey on stderr" {
  cat > .claude/backlog-project.json << 'JSON'
{
  "owner": "testowner",
  "repo": "testrepo",
  "project_number": 1,
  "project_id": "PVT_test",
  "status_field_id": "PVTF_test",
  "status_options": {
    "Todo": "opt_todo",
    "In Progress": "opt_inprogress"
  }
}
JSON
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"status_options.Done"* ]]
}

# ---------------------------------------------------------------------------
# Project not found
# ---------------------------------------------------------------------------

@test "project not found: exits 1 with message on stderr" {
  touch "$GH_MOCK_DIR/project_not_found"
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not found or inaccessible"* ]]
}

# ---------------------------------------------------------------------------
# Project ID mismatch
# ---------------------------------------------------------------------------

@test "project ID mismatch: exits 1 with message on stderr" {
  echo '{"id": "PVT_different"}' > "$GH_MOCK_DIR/project_view.json"
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ID mismatch"* ]]
}

# ---------------------------------------------------------------------------
# Missing canonical labels
# ---------------------------------------------------------------------------

@test "missing canonical label: exits 1 naming the missing label on stderr" {
  # Omit type:security from the fixture
  cat > "$GH_MOCK_DIR/labels.json" << 'JSON'
[
  {"name": "type:feature"}, {"name": "type:bug"},
  {"name": "type:performance"}, {"name": "type:dx"}, {"name": "type:tech-debt"},
  {"name": "type:reliability"}, {"name": "type:compliance"}, {"name": "type:spike"},
  {"name": "type:external-blocker"},
  {"name": "priority:P0"}, {"name": "priority:P1"}, {"name": "priority:P2"}, {"name": "priority:P3"},
  {"name": "effort:XS"}, {"name": "effort:S"}, {"name": "effort:M"}, {"name": "effort:L"}, {"name": "effort:XL"},
  {"name": "needs-clarification"}
]
JSON
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Missing canonical labels"* ]]
  [[ "$output" == *"type:security"* ]]
}

# ---------------------------------------------------------------------------
# Label fetch failure
# ---------------------------------------------------------------------------

@test "label fetch failure: exits 1 with message on stderr" {
  touch "$GH_MOCK_DIR/label_fail"
  run "$BACKLOG_PREFLIGHT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Failed to fetch label catalog"* ]]
}
