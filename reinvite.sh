#!/bin/bash

ORG_NAME="UNC-DATA-730"

CLASSROOM_IDS=(
  "275640"
  "276987"
)

get_assignment_repos() {
  local classroom_id="$1"

  echo "Getting assignments for classroom $classroom_id..."

  assignments=$(gh api "/classrooms/$classroom_id/assignments" --jq '.[].id' 2>/dev/null)

  if [ -z "$assignments" ]; then
    echo "  No assignments found for classroom $classroom_id"
    return
  fi

  echo "$assignments" | while read assignment_id; do
    echo "  Checking assignment $assignment_id..."

    accepted_assignments=$(gh api "/assignments/$assignment_id/accepted_assignments" --jq '.[] | .repository.full_name' 2>/dev/null)

    if [ -n "$accepted_assignments" ]; then
      echo "$accepted_assignments" | while read repo_full_name; do
        repo_name=$(echo "$repo_full_name" | cut -d'/' -f2)
        echo "    Found repository: $repo_name"
        process_repo_invites "$repo_name"
      done
    fi
  done
}

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

  if [ -n "$invites" ]; then
    echo "$invites" | while IFS=',' read invite_id invitee; do
      echo "  Processing GitHub Classroom invitation for user: $invitee"
      echo "    -> Deleting invitation ID $invite_id from $full_repo_name..."
      gh api "repos/$full_repo_name/invitations/$invite_id" -X DELETE --silent
      echo "    -> Re-creating invitation for user: $invitee"
      gh api "repos/$full_repo_name/collaborators/$invitee" -X PUT -f permission=write --silent
    done
  else
    echo "  No pending GitHub Classroom invites found for $full_repo_name"
  fi
  echo ""
}

echo "Starting GitHub invite processing for organization: $ORG_NAME"
echo "============================================================"

for classroom_id in "${CLASSROOM_IDS[@]}"; do
  echo "Processing classroom: $classroom_id"
  echo "--------------------"
  get_assignment_repos "$classroom_id"
  echo ""
done

echo "Processing complete!"
