#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(dirname "$(dirname "$BATS_TEST_FILENAME")")"
  RESOLVE_MILESTONE="$REPO_ROOT/bin/resolve-milestone"

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
  "project_number": 1
}
JSON

  # gh mock — reads fixtures from $GH_MOCK_DIR at runtime (not expanded here)
  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "api" ]]; then
  path="${1:-}"
  if [[ "$path" =~ ^repos/[^/]+/[^/]+/milestones ]]; then
    if [[ -f "$GH_MOCK_DIR/milestones_fail" ]]; then
      echo "HTTP 401: Bad credentials" >&2
      exit 1
    fi
    cat "$GH_MOCK_DIR/milestones.json"
    exit 0
  fi
  echo "Unhandled api path: $path" >&2; exit 1
else
  echo "Unhandled gh subcmd: $subcmd ($*)" >&2; exit 1
fi
SCRIPT
  chmod +x "$MOCK_BIN/gh"

  # Default fixture: no milestones
  echo '[]' > "$GH_MOCK_DIR/milestones.json"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$GH_MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

milestone() {
  local number="$1" title="$2" due_on="$3"
  if [[ -n "$due_on" ]]; then
    printf '{"number": %s, "title": "%s", "due_on": "%s"}' "$number" "$title" "$due_on"
  else
    printf '{"number": %s, "title": "%s", "due_on": null}' "$number" "$title"
  fi
}

# ---------------------------------------------------------------------------
# No-arg: Active Release resolution
# ---------------------------------------------------------------------------

@test "no-arg: exits 0 with earliest-due-date milestone as the Active Release" {
  printf '[%s, %s]' \
    "$(milestone 8 'v0.6.0' '2026-07-14T00:00:00Z')" \
    "$(milestone 11 'v0.6.2' '2026-06-01T00:00:00Z')" \
    > "$GH_MOCK_DIR/milestones.json"

  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 0 ]]

  number=$(echo "$output" | jq -r '.number')
  title=$(echo "$output" | jq -r '.title')
  [[ "$number" == "11" ]]
  [[ "$title" == "v0.6.2" ]]
}

@test "no-arg: exits 2 with 'No open milestones found.' on stderr when zero open milestones" {
  echo '[]' > "$GH_MOCK_DIR/milestones.json"

  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"No open milestones found."* ]]
}

# ---------------------------------------------------------------------------
# Named-arg resolution — two-pass match
# ---------------------------------------------------------------------------

@test "named-arg: exits 0 via substring match (pass 1)" {
  printf '[%s, %s]' \
    "$(milestone 8 'v0.6.0' '2026-07-14T00:00:00Z')" \
    "$(milestone 11 'v0.6.2' '2026-06-01T00:00:00Z')" \
    > "$GH_MOCK_DIR/milestones.json"

  run "$RESOLVE_MILESTONE" "0.6.2"
  [[ "$status" -eq 0 ]]

  number=$(echo "$output" | jq -r '.number')
  title=$(echo "$output" | jq -r '.title')
  [[ "$number" == "11" ]]
  [[ "$title" == "v0.6.2" ]]
}

@test "named-arg: exits 0 via stripped-v fallback match (pass 2)" {
  # Title has no leading 'v'; only matches once both arg and title are
  # stripped of a leading 'v' and compared for equality — substring pass
  # would not match "v0.6.2" against "0.6.2" title without this fallback.
  printf '[%s]' "$(milestone 11 '0.6.2' '2026-06-01T00:00:00Z')" \
    > "$GH_MOCK_DIR/milestones.json"

  run "$RESOLVE_MILESTONE" "v0.6.2"
  [[ "$status" -eq 0 ]]

  number=$(echo "$output" | jq -r '.number')
  title=$(echo "$output" | jq -r '.title')
  [[ "$number" == "11" ]]
  [[ "$title" == "0.6.2" ]]
}

@test "named-arg: exits 1 when no milestone matches either pass" {
  printf '[%s]' "$(milestone 8 'v0.6.0' '2026-07-14T00:00:00Z')" \
    > "$GH_MOCK_DIR/milestones.json"

  run "$RESOLVE_MILESTONE" "v9.9.9"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"No open milestone matching"* ]]
}

# ---------------------------------------------------------------------------
# Infrastructure failures — exit 1, unchanged
# ---------------------------------------------------------------------------

@test "exits 1 when .claude/backlog-project.json is missing" {
  rm .claude/backlog-project.json

  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 1 ]]
}

@test "exits 1 when the gh API call fetching milestones fails" {
  touch "$GH_MOCK_DIR/milestones_fail"

  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Failed to fetch milestones"* ]]
}
