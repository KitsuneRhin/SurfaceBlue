#!/usr/bin/env bash
set -euo pipefail

LOG=/tmp/surface-smoke-$(date -u +%Y%m%dT%H%M%SZ).log
echo "Surface smoke test started at $(date -u)" | tee "$LOG"

# 1) Kernel
echo "== Kernel ==" | tee -a "$LOG"
uname -a | tee -a "$LOG"

# 2) Check packages (rpm-based)
echo "== Packages ==" | tee -a "$LOG"
for pkg in kernel-surface iptsd libwacom-surface libwacom-surface-data; do
  if rpm -q "$pkg" >/dev/null 2>&1; then
    echo "OK: $pkg installed" | tee -a "$LOG"
  else
    echo "MISSING: $pkg" | tee -a "$LOG"
  fi
done

# 3) iptsd service
echo "== iptsd service ==" | tee -a "$LOG"
if systemctl list-unit-files | grep -q '^iptsd'; then
  systemctl status iptsd --no-pager | sed -n '1,10p' | tee -a "$LOG"
  systemctl is-enabled iptsd && echo "iptsd is enabled" | tee -a "$LOG" || echo "iptsd not enabled" | tee -a "$LOG"
else
  echo "iptsd service not present" | tee -a "$LOG"
fi

# 4) Input devices presence
echo "== Input devices ==" | tee -a "$LOG"
ls -l /dev/input || true
echo "Listing event devices:" | tee -a "$LOG"
for ev in /dev/input/event*; do
  [ -e "$ev" ] || continue
  echo "Device: $ev" | tee -a "$LOG"
  udevadm info --query=all --name="$ev" 2>/dev/null | sed -n '1,20p' | tee -a "$LOG"
done

# 5) Optional: run evtest or libinput if installed (non-interactive)
if command -v evtest >/dev/null 2>&1; then
  echo "== evtest sample (first device, 2s) ==" | tee -a "$LOG"
  DEV=$(ls /dev/input/event* | head -n1)
  if [ -n "$DEV" ]; then
    timeout 2 evtest "$DEV" 2>&1 | sed -n '1,40p' | tee -a "$LOG" || true
  fi
elif command -v libinput >/dev/null 2>&1; then
  echo "== libinput list-devices ==" | tee -a "$LOG"
  libinput list-devices | tee -a "$LOG"
else
  echo "evtest/libinput not installed; skipping dynamic input test" | tee -a "$LOG"
fi

# 6) Quick touchscreen test hint (manual)
echo "== Manual touchscreen test ==" | tee -a "$LOG"
echo "Please touch the screen and verify cursor/mouse events or run 'evtest' interactively." | tee -a "$LOG"

echo "Smoke test finished at $(date -u)" | tee -a "$LOG"
echo "Log saved to $LOG"
