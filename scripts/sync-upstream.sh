#!/usr/bin/env bash
set -euo pipefail
set -x

# Configuration: upstream repo and paths
UPSTREAM_REPO="https://github.com/ublue-os/bluefin.git"
UPSTREAM_REF="main"                       # change if you want a tag/branch
UPSTREAM_SUBPATH="images/bluefin-dx"   # path inside upstream repo that contains Containerfile/system_files
LOCAL_UPSTREAM_DIR="upstream/bluefin-dx"
METADATA_FILE="upstream/metadata.json"
SYNC_BRANCH="upstream-sync/bluefin-dx"
REVIEW_LABEL="needs-manual-review"

# Packages that indicate kernel/driver/ABI-sensitive changes
CRITICAL_PACKAGES_REGEX="kernel|kernel-surface|nvidia|libwacom|iptsd|dkms|nvidia-driver"

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

# Ensure upstream subpath exists
if [ ! -d "$TMPDIR/upstream-repo/$UPSTREAM_SUBPATH" ]; then
  echo "Upstream subpath not found: $UPSTREAM_SUBPATH"
  exit 3
fi

# Copy the relevant subpath (Containerfile + system_files)
mkdir -p "$LOCAL_UPSTREAM_DIR"
rsync -a --delete "$TMPDIR/upstream-repo/$UPSTREAM_SUBPATH/" "$LOCAL_UPSTREAM_DIR/"

# Read upstream Containerfile FROM line (if present)
UPSTREAM_CONTAINERFILE="$LOCAL_UPSTREAM_DIR/Containerfile"
UPSTREAM_FROM_LINE=""
if [ -f "$UPSTREAM_CONTAINERFILE" ]; then
  UPSTREAM_FROM_LINE=$(grep -i '^FROM ' "$UPSTREAM_CONTAINERFILE" | head -n1 || true)
fi
echo "Upstream FROM: $UPSTREAM_FROM_LINE"

# Extract Fedora major version if present (e.g., fedora:42 or fedora/42)
UPSTREAM_FEDORA_MAJOR=""
if echo "$UPSTREAM_FROM_LINE" | grep -Ei 'fedora[^0-9]*([0-9]{2})' >/dev/null 2>&1; then
  UPSTREAM_FEDORA_MAJOR=$(echo "$UPSTREAM_FROM_LINE" | sed -E 's/.*fedora[^0-9]*([0-9]{2}).*/\1/i' || true)
fi

# Heuristic: extract dnf/dnf5 install package lists from upstream and local Containerfiles
extract_pkgs() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  # capture tokens after "dnf" or "dnf5" install, handle line continuations
  grep -E "dnf(5)? .*install" -n "$file" 2>/dev/null \
    | sed -E 's/.*install[[:space:]]+//I' \
    | sed -E 's/\\$//g' \
    | tr -s ' ' '\n' \
    | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//' \
    | sed -E 's/^-y$//;s/^-q$//;s/^-.*$//' \
    | grep -E '\w' || true
}

UPSTREAM_PKGS=$(extract_pkgs "$UPSTREAM_CONTAINERFILE" | sort -u || true)
LOCAL_PKGS=$(extract_pkgs "Containerfile" | sort -u || true)

# Detect critical package changes (added/removed)
PKGS_ADDED=$(comm -13 <(echo "$LOCAL_PKGS") <(echo "$UPSTREAM_PKGS") || true)
PKGS_REMOVED=$(comm -23 <(echo "$LOCAL_PKGS") <(echo "$UPSTREAM_PKGS") || true)

# Determine if any critical packages changed
CRITICAL_CHANGE=0
if echo "$UPSTREAM_PKGS" | grep -E "$CRITICAL_PACKAGES_REGEX" >/dev/null 2>&1 || \
   echo "$LOCAL_PKGS" | grep -E "$CRITICAL_PACKAGES_REGEX" >/dev/null 2>&1; then
  # If any of the critical package names appear in the diff sets, mark critical
  if echo "$PKGS_ADDED" | grep -E "$CRITICAL_PACKAGES_REGEX" >/dev/null 2>&1 || \
     echo "$PKGS_REMOVED" | grep -E "$CRITICAL_PACKAGES_REGEX" >/dev/null 2>&1; then
    CRITICAL_CHANGE=1
  fi
fi

# Decide whether to block automatic sync
BLOCKED=0
BLOCK_REASON=""

# Block if upstream moves to Fedora > 42
if [ -n "$UPSTREAM_FEDORA_MAJOR" ]; then
  if [ "$UPSTREAM_FEDORA_MAJOR" -gt 42 ]; then
    BLOCKED=1
    BLOCK_REASON="Upstream base targets Fedora $UPSTREAM_FEDORA_MAJOR which is unsupported (allowed: Fedora 42)."
  fi
fi

# Block if critical package changes detected
if [ "$CRITICAL_CHANGE" -eq 1 ]; then
  BLOCKED=1
  if [ -n "$BLOCK_REASON" ]; then
    BLOCK_REASON="$BLOCK_REASON; critical package changes detected (kernel/driver packages changed)."
  else
    BLOCK_REASON="Critical package changes detected (kernel/driver packages changed)."
  fi
fi

# Update metadata.json with commit and timestamp and block info
UPSTREAM_COMMIT=$(git -C "$TMPDIR/upstream-repo" rev-parse --short HEAD)
UPSTREAM_URL="$UPSTREAM_REPO"
mkdir -p "$(dirname "$METADATA_FILE")"
cat > "$METADATA_FILE" <<EOF
{
  "repo": "$UPSTREAM_URL",
  "ref": "$UPSTREAM_REF",
  "commit": "$UPSTREAM_COMMIT",
  "synced_at": "$(date --utc +%Y-%m-%dT%H:%M:%SZ)",
  "from_line": "$(echo "$UPSTREAM_FROM_LINE" | sed 's/"/\\"/g')",
  "fedora_major": "$UPSTREAM_FEDORA_MAJOR",
  "blocked": $BLOCKED,
  "block_reason": "$(echo "$BLOCK_REASON" | sed 's/"/\\"/g')"
}
EOF

# Stage changes
git add "$LOCAL_UPSTREAM_DIR" "$METADATA_FILE"

# If no changes, exit cleanly
if git diff --cached --quiet; then
  echo "No upstream changes detected."
  git reset -- "$LOCAL_UPSTREAM_DIR" "$METADATA_FILE"
  exit 0
fi

# Create a branch and commit
git checkout -b "$SYNC_BRANCH"
git commit -m "chore(upstream): sync bluefin-dx @ $UPSTREAM_COMMIT"
git push --set-upstream origin "$SYNC_BRANCH"

# Create a PR and label it if blocked
PR_TITLE="Sync upstream bluefin-dx: $UPSTREAM_COMMIT"
PR_BODY="Automated upstream sync of bluefin-dx @ $UPSTREAM_COMMIT

**Upstream FROM:** $UPSTREAM_FROM_LINE
**Fedora major:** $UPSTREAM_FEDORA_MAJOR

**Detected package changes (upstream packages):**
$UPSTREAM_PKGS

**Detected package changes (local packages):**
$LOCAL_PKGS

**Blocked:** $BLOCKED
**Block reason:** $BLOCK_REASON
"

if command -v gh >/dev/null 2>&1; then
  # Create PR
  PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main --head "$SYNC_BRANCH" --label "automated-sync" --assignee @me --json url --jq .url || true)
  echo "PR created: $PR_URL"

  if [ "$BLOCKED" -eq 1 ]; then
    # Add review label and comment
    gh pr edit "$PR_URL" --add-label "$REVIEW_LABEL" || true
    gh pr comment "$PR_URL" --body "Automated sync blocked: $BLOCK_REASON. Please review kernel/driver/base-image changes before merging." || true
  fi
else
  # If gh is not available, push branch and print instructions
  echo "Branch pushed: $SYNC_BRANCH"
  echo "Create a PR from $SYNC_BRANCH into main to review upstream changes."
  if [ "$BLOCKED" -eq 1 ]; then
    echo "NOTE: This sync is BLOCKED for automatic merge. Reason: $BLOCK_REASON"
    echo "Please create a PR and add the label: $REVIEW_LABEL"
  fi
fi

# Exit with success (we created a branch/PR). CI or maintainers will review.
exit 0
