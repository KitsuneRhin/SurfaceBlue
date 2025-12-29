#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_DIR="upstream/bluefin-dx"
LOCAL_CONTAINERFILE="Containerfile"
LOCAL_SYSTEM_FILES="system_files"

echo "=== Upstream metadata ==="
cat upstream/metadata.json || echo "(no metadata found)"

echo
echo "=== Containerfile diff ==="
if [ -f "$UPSTREAM_DIR/Containerfile" ]; then
  diff -u "$UPSTREAM_DIR/Containerfile" "$LOCAL_CONTAINERFILE" || true
else
  echo "(no upstream Containerfile found)"
fi

echo
echo "=== system_files diff (recursive) ==="
if [ -d "$UPSTREAM_DIR/system_files" ]; then
  diff -ru "$UPSTREAM_DIR/system_files" "$LOCAL_SYSTEM_FILES" || true
else
  echo "(no upstream system_files found)"
fi

echo
echo "=== Quick package-change summary (heuristic) ==="
# Heuristic: look for 'dnf' or 'dnf5' install lines in Containerfile
grep -E "dnf(5)? install" -n "$UPSTREAM_DIR/Containerfile" 2>/dev/null || true
grep -E "dnf(5)? install" -n "$LOCAL_CONTAINERFILE" 2>/dev/null || true

echo
echo "=== End of diff ==="
