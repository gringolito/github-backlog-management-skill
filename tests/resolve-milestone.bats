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
  "repo": "testrepo"
}
JSON

  # Default: two open milestones
  cat > "$GH_MOCK_DIR/milestones.json" << 'JSON'
[
  {"number": 10, "title": "v0.7.0", "due_on": "2026-07-13T00:00:00Z"},
  {"number": 9,  "title": "v0.6.0", "due_on": "2026-06-30T00:00:00Z"}
]
JSON

  cat > "$MOCK_BIN/gh" << 'SCRIPT'
#!/usr/bin/env bash
subcmd="${1:-}"
shift || true

if [[ "$subcmd" == "api" ]]; then
  [[ -f "$GH_MOCK_DIR/api_fail" ]] && { echo "API error" >&2; exit 1; }
  cat "$GH_MOCK_DIR/milestones.json"
  exit 0
fi

echo "Unhandled gh subcmd: $subcmd ($*)" >&2; exit 1
SCRIPT
  chmod +x "$MOCK_BIN/gh"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN" "$GH_MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

@test "--exclude missing arg: exits 1 with usage error on stderr" {
  run "$RESOLVE_MILESTONE" --exclude
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"--exclude requires"* ]]
}

@test "unknown option: exits 1 with usage error on stderr" {
  run "$RESOLVE_MILESTONE" --foo
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"unknown option"* ]]
}

@test "multiple positional args: exits 1 with usage error on stderr" {
  run "$RESOLVE_MILESTONE" v0.6.0 v0.7.0
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"multiple positional"* ]]
}

@test "positional arg combined with --exclude: exits 1 with usage error on stderr" {
  run "$RESOLVE_MILESTONE" v0.6.0 --exclude v0.7.0
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"cannot combine"* ]]
}

# ---------------------------------------------------------------------------
# Missing metadata file
# ---------------------------------------------------------------------------

@test "missing metadata file: exits 1" {
  rm .claude/backlog-project.json
  run "$RESOLVE_MILESTONE"
  [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# API failure
# ---------------------------------------------------------------------------

@test "API failure: exits 1 with message on stderr" {
  touch "$GH_MOCK_DIR/api_fail"
  run "$RESOLVE_MILESTONE"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Failed to fetch milestones"* ]]
}

# ---------------------------------------------------------------------------
# Named arg — pass-1 substring match
# ---------------------------------------------------------------------------

@test "named arg substring match: returns milestone with matching title" {
  run "$RESOLVE_MILESTONE" "0.6"
  [[ "$status" -eq 0 ]]
  title=$(echo "$output" | jq -r '.title')
  [[ "$title" == "v0.6.0" ]]
}

# ---------------------------------------------------------------------------
# Named arg — pass-2 strip-v match
# ---------------------------------------------------------------------------

@test "named arg strip-v match: returns milestone when leading v is stripped" {
  # "0.6.0" won't substring-match "v0.7.0" or "v0.6.0" in pass-1 (contains check
  # would match "v0.6.0" via contains("0.6.0") — so use a version that needs strip-v)
  cat > "$GH_MOCK_DIR/milestones.json" << 'JSON'
[{"number": 9, "title": "v0.6.0", "due_on": "2026-06-30T00:00:00Z"}]
JSON
  # Pass 1: ascii_downcase of "v0.6.0" contains ascii_downcase of "0.6.0" → actually
  # this WOULD match in pass 1. Use a title that only matches after strip-v:
  # e.g. title "release-0.5" and arg "release-0.5" — but the script strips leading v
  # from title with ltrimstr("v"). Let's use a clean non-v title to force pass 2 only.
  cat > "$GH_MOCK_DIR/milestones.json" << 'JSON'
[{"number": 5, "title": "0.5.0", "due_on": "2026-05-01T00:00:00Z"}]
JSON
  # arg "v0.5.0": pass-1 contains("v0.5.0") in "0.5.0" → false; pass-2 strips v → "0.5.0" == "0.5.0" → match
  run "$RESOLVE_MILESTONE" "v0.5.0"
  [[ "$status" -eq 0 ]]
  title=$(echo "$output" | jq -r '.title')
  [[ "$title" == "0.5.0" ]]
}

# ---------------------------------------------------------------------------
# Named arg — no match
# ---------------------------------------------------------------------------

@test "named arg no match: exits 1 with message on stderr" {
  run "$RESOLVE_MILESTONE" "0.5.0"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"No open milestone matching"* ]]
}

# ---------------------------------------------------------------------------
# No-arg with --exclude
# ---------------------------------------------------------------------------

@test "no-arg with --exclude: filters out excluded milestone" {
  run "$RESOLVE_MILESTONE" --exclude "v0.7.0"
  [[ "$status" -eq 0 ]]
  title=$(echo "$output" | jq -r '.title')
  [[ "$title" == "v0.6.0" ]]
}

# ---------------------------------------------------------------------------
# No-arg — no milestones
# ---------------------------------------------------------------------------

@test "no-arg no milestones: exits 1 with message on stderr" {
  echo '[]' > "$GH_MOCK_DIR/milestones.json"
  run "$RESOLVE_MILESTONE"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"No open milestones found"* ]]
}

# ---------------------------------------------------------------------------
# No-arg — sorts by due_on ascending
# ---------------------------------------------------------------------------

@test "no-arg sort: returns milestone with earliest due_on" {
  # Fixture lists v0.7.0 first in JSON order but v0.6.0 has an earlier due_on
  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 0 ]]
  title=$(echo "$output" | jq -r '.title')
  [[ "$title" == "v0.6.0" ]]
}

# ---------------------------------------------------------------------------
# No-arg — null due_on sorts last
# ---------------------------------------------------------------------------

@test "no-arg sort: milestone with null due_on comes after dated milestones" {
  cat > "$GH_MOCK_DIR/milestones.json" << 'JSON'
[
  {"number": 1, "title": "v0.5.0", "due_on": null},
  {"number": 2, "title": "v0.6.0", "due_on": "2026-06-30T00:00:00Z"}
]
JSON
  run "$RESOLVE_MILESTONE"
  [[ "$status" -eq 0 ]]
  title=$(echo "$output" | jq -r '.title')
  [[ "$title" == "v0.6.0" ]]
}
