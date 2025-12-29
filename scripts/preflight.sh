#!/usr/bin/env bash
set -euo pipefail

# Files/paths to verify inside the image
declare -a CHECK_PATHS=(
  "/usr/lib/systemd/system/surface-kernel-install.service"
  "/usr/lib/systemd/system-preset/99-surfaceblue.preset"
  "/etc/yum.repos.d/linux-surface.repo"
)

echo "Running preflight checks inside image..."

MISSING=0
for p in "${CHECK_PATHS[@]}"; do
  if [ -e "$p" ]; then
    echo "OK: $p"
  else
    echo "MISSING: $p"
    MISSING=1
  fi
done

# Optional: check Containerfile presence (for traceability)
if [ -f /Containerfile ]; then
  echo "OK: /Containerfile present"
else
  echo "WARN: /Containerfile not present in image root (not required)"
fi

if [ "$MISSING" -ne 0 ]; then
  echo "Preflight failed: missing required files."
  exit 2
fi

echo "Preflight checks passed."
exit 0
