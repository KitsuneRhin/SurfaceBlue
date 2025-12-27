#!/bin/bash
set -ouex pipefail

# Ensure systemd sees unit files copied from system_files/
systemctl daemon-reload

# Disable broken third-party repos during build
if [ -f /etc/yum.repos.d/negativo17-multimedia.repo ]; then
    dnf5 config-manager --set-disabled negativo17-multimedia || true
fi

# Install base packages
dnf5 install -y tmux

# Enable first-boot kernel installer
systemctl enable surface-kernel-install.service

# Enable podman socket
systemctl enable podman.socket