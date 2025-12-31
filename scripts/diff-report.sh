#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="upstream"
REPORT_FILE="${REPORT_DIR}/diff-report.txt"

mkdir -p "${REPORT_DIR}"

echo "Generating enhanced upstream diff report..."
echo "==========================================" > "${REPORT_FILE}"
echo "UPSTREAM DIFF REPORT" >> "${REPORT_FILE}"
echo "Generated: $(date -u)" >> "${REPORT_FILE}"
echo "==========================================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# 1. Upstream commit summary
echo "### Upstream Commit Summary" >> "${REPORT_FILE}"
git log --oneline upstream/main..HEAD >> "${REPORT_FILE}" || echo "(no commit summary available)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# 2. Changed files
echo "### Changed Files (Added/Modified/Deleted)" >> "${REPORT_FILE}"
git diff --name-status upstream/main..HEAD >> "${REPORT_FILE}" || echo "(no file changes)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# 3. Package diff (RPMs)
echo "### Package Changes (RPM diff)" >> "${REPORT_FILE}"
if command -v rpm-ostree >/dev/null 2>&1; then
    echo "Old tree:" >> "${REPORT_FILE}"
    rpm-ostree db diff --old upstream --new . >> "${REPORT_FILE}" || echo "(rpm-ostree diff failed)" >> "${REPORT_FILE}"
else
    echo "(rpm-ostree not available in CI environment)" >> "${REPORT_FILE}"
fi
echo "" >> "${REPORT_FILE}"

# 4. Kernel version diff
echo "### Kernel Version Changes" >> "${REPORT_FILE}"
OLD_KERNEL=$(grep -R "kernel" upstream/metadata.json 2>/dev/null || echo "unknown")
NEW_KERNEL=$(uname -r || echo "unknown")
echo "Old kernel: ${OLD_KERNEL}" >> "${REPORT_FILE}"
echo "New kernel: ${NEW_KERNEL}" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# 5. Containerfile diff
echo "### Containerfile Diff" >> "${REPORT_FILE}"
git diff upstream/main..HEAD -- Containerfile >> "${REPORT_FILE}" || echo "(no Containerfile changes)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# 6. Bootc layer diff (if metadata exists)
echo "### Bootc Layer Diff" >> "${REPORT_FILE}"
if [ -f upstream/metadata.json ]; then
    jq '.layers' upstream/metadata.json >> "${REPORT_FILE}" || echo "(metadata parse failed)" >> "${REPORT_FILE}"
else
    echo "(no metadata.json found)" >> "${REPORT_FILE}"
fi
echo "" >> "${REPORT_FILE}"

# 7. Full git diff (optional)
echo "### Full Git Diff" >> "${REPORT_FILE}"
git diff upstream/main..HEAD >> "${REPORT_FILE}" || echo "(no full diff)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "Enhanced diff report written to ${REPORT_FILE}"
