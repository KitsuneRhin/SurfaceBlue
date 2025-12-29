## Upstream Sync Review Checklist

**Upstream commit:** `{{upstream_commit}}`

### Compatibility checks (required)
- [ ] **Base image**: Confirm `FROM` line targets Fedora 42 or an allowed base.
- [ ] **Kernel packages**: Verify no unintended kernel or kernel-module changes (kernel, kernel-surface, nvidia, dkms).
- [ ] **Driver packages**: Verify libwacom / libwacom-surface, iptsd, and other driver packages are compatible.
- [ ] **System files**: Review `system_files/` diffs for changes to systemd units, presets, or repo files.
- [ ] **Smoke test plan**: Assign a test device/VM and list the smoke tests to run (kernel version, iptsd status, touchscreen test).

### If any of the above are changed:
- Add label: `needs-manual-review`
- Do not merge until a maintainer confirms tests pass on hardware.

### Notes
- If this PR is blocked due to Fedora version bump or kernel/driver changes, create an `experimental` branch to track upstream work and perform porting there.
