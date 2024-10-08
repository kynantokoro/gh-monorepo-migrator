#!/bin/bash

# Set your repository details
ORG="kynantokoro"  # Replace with your organization name
REPO="multirepo1"  # Replace with your repository name
BRANCH="main"      # Branch name (replace if needed)
OUTPUT_FILE="../commit-pr-mapping.jsonl"  # Output file for commits and PR mapping
SUBDIRECTORY_NAME="multirepo1" # Replace with the subdirectory name to be used the new mono-repository. You can just use the old repository name.
FIRST=2  # Adjust based on how many commits you want to retrieve at once

# Clear or create the output file
> "$OUTPUT_FILE"

echo "Starting mapping of commits to pull requests..."


# GraphQL query to get commits and associated PRs
query='
query GetCommitsAndPRNumber($owner: String!, $repo: String!, $branchName: String!, $first: Int, $after: String) {
  repository(owner: $owner, name: $repo) {
    ref(qualifiedName: $branchName) {
      target {
        ... on Commit {
          oid
          history(first: $first, after: $after) {
            nodes {
              oid
              associatedPullRequests(first: 1) {
                nodes {
                  number
                }
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }
  }
}'

# Initialize cursor and keep fetching while there's more data
cursor=""

while :; do
  echo "Fetching commits with cursor: $cursor"

  # Use the gh API to call GraphQL
  response=$(gh api graphql -F query="$query" -F owner="$ORG" -F repo="$REPO" -F branchName="$BRANCH" -F first="$FIRST" -F after="$cursor")

  # Output the response for debugging
  echo "Response: $response"

  # Process the response and extract commit hash and PR number
  echo "$response" | jq -r '
    .data.repository.ref.target.history.nodes[]? | 
    {
      commit: .oid, 
      pr_number: .associatedPullRequests.nodes[]?.number
    }' >> "$OUTPUT_FILE"

  # Check if there's a next page
  hasNextPage=$(echo "$response" | jq -r '.data.repository.ref.target.history.pageInfo.hasNextPage')
  if [[ "$hasNextPage" == "false" ]]; then
    echo "No more commits to fetch."
    break
  fi

  # Update the cursor for the next page
  cursor=$(echo "$response" | jq -r '.data.repository.ref.target.history.pageInfo.endCursor')
done

echo "Mapping saved to $OUTPUT_FILE"

# Prepare for git filter-repo using the mapping file
echo "Processing mapping for git filter-repo..."

# Map commit hashes to PR numbers for git filter-repo
mapping=$(jq -r '. | "\(.commit)=\(.pr_number)"' "$OUTPUT_FILE" | sed 's/ //g')
echo "Mapping Bash: $mapping"

# Run git filter-repo to modify commit messages based on the mapping
git filter-repo --commit-callback '
import re

# Build a dictionary from the mapping file
commit_to_pr = {line.split("=")[0].strip(): line.split("=")[1].strip() for line in """'"$mapping"'""".splitlines()}
print(f"Mapping: {commit_to_pr}")

commit_hash = commit.original_id.decode("utf-8")
print(f"Commit hash: {commit_hash}")
pr_number = commit_to_pr.get(commit_hash)
print(f"PR number: {pr_number}")

if pr_number:
    msg = commit.message.decode("utf-8")
    print(f"Original commit message for {commit_hash}:\n{msg}")
    
    if msg.startswith("Merge pull request #"):
        # Simulate modification for merge commits
        newmsg = re.sub(r"(Merge pull request #)(\d+)", r"Merge pull request '"$ORG"'/'"$REPO"'#\2", msg)
    else:
        # Simulate appending for regular commits
        newmsg = f"{msg}\nOriginal PR: '"$ORG"'/'"$REPO"'#{pr_number} (repo migrated)"

    commit.message = newmsg.encode("utf-8")
'

git filter-repo --to-subdirectory-filter "$SUBDIRECTORY_NAME"
