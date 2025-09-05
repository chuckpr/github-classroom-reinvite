#!/bin/bash

ORG_NAME="UNC-DATA-730"

USER_HANDLES=(
  "kdilz"
)

REPO_PREFIXES=(
  "unit-1-assignment-"
  "unit-2-assignment-"
  "unit-3-assignment-"
  "unit-4-assignment-"
)

process_repo_invites() {
  local repo_name="$1"
  local full_repo_name="$ORG_NAME/$repo_name"

  echo "Checking repository: $full_repo_name"

  if ! gh api "repos/$full_repo_name" >/dev/null 2>&1; then
    echo "  Repository $full_repo_name does not exist or is not accessible. Skipping."
    echo ""
    return
  fi

  echo "  Repository exists. Processing invitations..."

  invites=$(gh api "repos/$full_repo_name/invitations" --jq '.[] | select(.inviter.login == "github-classroom[bot]") | "\(.id),\(.invitee.login)"' 2>/dev/null)
  # invites=$(gh api "repos/$full_repo_name/invitations" --jq '.[] | "\(.id),\(.invitee.login)"' 2>/dev/null)

  if [ -n "$invites" ]; then
    echo "$invites" | while IFS=',' read invite_id invitee; do
      echo "  Processing invitation for user: $invitee"
      echo "    -> Deleting invitation ID $invite_id from $full_repo_name..."
      gh api "repos/$full_repo_name/invitations/$invite_id" -X DELETE --silent
      echo "    -> Re-creating invitation for user: $invitee"
      gh api "repos/$full_repo_name/collaborators/$invitee" -X PUT -f permission=write --silent
    done
  else
    echo "  No pending invites found for $full_repo_name"
  fi
  echo ""
}

echo "Starting GitHub invite processing for organization: $ORG_NAME"
echo "============================================================"

for user in "${USER_HANDLES[@]}"; do
  echo "Processing user: $user"
  echo "--------------------"

  for prefix in "${REPO_PREFIXES[@]}"; do
    repo_name="${prefix}${user}"
    process_repo_invites "$repo_name"
  done
done

echo "Processing complete!"
