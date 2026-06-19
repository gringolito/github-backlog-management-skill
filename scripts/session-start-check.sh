#!/usr/bin/env bash

[ -f ".claude/backlog-project.json" ] || exit 0

remote_url=$(git remote get-url origin 2>/dev/null)
if [[ "$remote_url" =~ ^https?://([^/]+) ]]; then
  gh_hostname="${BASH_REMATCH[1]}"
elif [[ "$remote_url" =~ ^[^@]+@([^:]+): ]]; then
  gh_hostname="${BASH_REMATCH[1]}"
else
  gh_hostname="github.com"
fi

missing_fields=()
for field in owner repo project_number project_id project_title project_url status_field_id; do
  val=$(jq -r --arg f "$field" '.[$f] // empty' .claude/backlog-project.json)
  [ -n "$val" ] || missing_fields+=("$field")
done
for option in Todo "In Progress" Done; do
  val=$(jq -r --arg o "$option" '.status_options[$o] // empty' .claude/backlog-project.json)
  [ -n "$val" ] || missing_fields+=("status_options.$option")
done

if [ ${#missing_fields[@]} -gt 0 ]; then
  joined=$(IFS=,; echo "${missing_fields[*]}")
  echo "WARNING: Backlog: .claude/backlog-project.json is missing required field(s): ${joined}"
  echo "  Fix: Re-run /initialize to regenerate the file."
  exit 0
fi

owner=$(jq -r '.owner' .claude/backlog-project.json)
project_number=$(jq -r '.project_number' .claude/backlog-project.json)
project_id=$(jq -r '.project_id' .claude/backlog-project.json)

# --- Check 1: required token scopes ---

auth_status=$(gh auth status --hostname "$gh_hostname" 2>&1)
scopes_line=$(echo "$auth_status" | grep "Token scopes:")

missing=()
for scope in repo project read:user; do
  echo "$scopes_line" | grep -q "'${scope}'" || missing+=("$scope")
done

owner_type=$(gh api "users/${owner}" --jq '.type' 2>/dev/null)
if [ "$owner_type" = "Organization" ]; then
  echo "$scopes_line" | grep -q "'read:org'" || missing+=("read:org")
fi

if [ ${#missing[@]} -gt 0 ]; then
  joined=$(IFS=,; echo "${missing[*]}")
  echo "WARNING: Backlog: missing token scope(s): ${joined}"
  echo "  Fix: gh auth refresh --hostname ${gh_hostname} --scopes ${joined}"
fi

# --- Check 2: project still exists and ID matches ---

live_id=$(gh project view "$project_number" --owner "$owner" --format json 2>/dev/null | jq -r '.id // empty')

if [ -z "$live_id" ]; then
  echo "WARNING: Backlog: project #${project_number} not found or inaccessible."
  echo "  Fix: Re-run /initialize to re-link the project, or delete .claude/backlog-project.json if the project was abandoned."
elif [ "$live_id" != "$project_id" ]; then
  echo "WARNING: Backlog: project ID mismatch (stored: ${project_id}, live: ${live_id})."
  echo "  Fix: Re-run /initialize to re-link the project."
fi

exit 0
