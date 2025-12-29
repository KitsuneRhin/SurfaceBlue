#!/usr/bin/env bash
set -euo pipefail

# Configuration: upstream repo and paths
UPSTREAM_REPO="https://github.com/ublue-os/bluefin.git"
UPSTREAM_REF="main"                       # change if you want a tag/branch
UPSTREAM_SUBPATH="container/bluefin-dx"   # path inside upstream repo that contains Containerfile/system_files
LOCAL_UPSTREAM_DIR="upstream/bluefin-dx"
METADATA_FILE="upstream/metadata.json"
SYNC_BRANCH="upstream-sync/bluefin-dx"

# Ensure working tree is clean
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree not clean. Commit or stash changes first."
  exit 2
fi

# Prepare temp dir
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Clone upstream shallow
git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$TMPDIR/upstream-repo"

# Copy the relevant subpath (Containerfile + system_files)
mkdir -p "$LOCAL_UPSTREAM_DIR"
rsync -a --delete "$TMPDIR/upstream-repo/$UPSTREAM_SUBPATH/" "$LOCAL_UPSTREAM_DIR/"

# Update metadata.json with commit and timestamp
UPSTREAM_COMMIT=$(git -C "$TMPDIR/upstream-repo" rev-parse --short HEAD)
UPSTREAM_URL="$UPSTREAM_REPO"
mkdir -p "$(dirname "$METADATA_FILE")"
cat > "$METADATA_FILE" <<EOF
{
  "repo": "$UPSTREAM_URL",
  "ref": "$UPSTREAM_REF",
  "commit": "$UPSTREAM_COMMIT",
  "synced_at": "$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Detect changes
git add "$LOCAL_UPSTREAM_DIR" "$METADATA_FILE"
if git diff --cached --quiet; then
  echo "No upstream changes detected."
  git reset -- "$LOCAL_UPSTREAM_DIR" "$METADATA_FILE"
  exit 0
fi

# Create a branch and commit
git checkout -b "$SYNC_BRANCH"
git commit -m "chore(upstream): sync bluefin-dx @ $UPSTREAM_COMMIT"
git push --set-upstream origin "$SYNC_BRANCH"

# Create a PR using GitHub CLI if available, otherwise print instructions
if command -v gh >/dev/null 2>&1; then
  gh pr create --title "Sync upstream bluefin-dx: $UPSTREAM_COMMIT" \
               --body "Automated upstream sync of bluefin-dx @ $UPSTREAM_COMMIT\n\nThis PR contains the upstream Containerfile and system_files snapshot for review." \
               --base main
  echo "PR created."
else
  echo "Branch pushed: $SYNC_BRANCH"
  echo "Create a PR from $SYNC_BRANCH into main to review upstream changes."
fi

exit 0
