#!/bin/bash

set -ouex pipefail

### Add linux-surface repo (Fedora42)
cat >/etc/yum.repos.d/linux-surface.repo << 'EOF'
[linux-surface]
name=linux-surface
baseurl=https://pkg.surfacelinux.com/fedora/f42
enabled=1
skip_if_unavailable=1
gpgkey=https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
gpgcheck=1
enabled_metadata=1
type=rpm-md
repo_gpgcheck=0
EOF


### Disable broken third-party repos during build
if [ -f /etc/yum.repos.d/negativo17-multimedia.repo ]; then
	dnf5 config-manager --set-disabled negativo17-multimedia || true
fi

### Uninstall base Fedora42 kernel
dnf5 remove -y \
	kernel-core \
	kernel-modules \
	kernel-modules-core \
	kernel-modules-extra \
	kernel-defaults || true


### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1



# this installs a package from fedora repos
dnf5 install -y tmux 

# Surface-specific kernel, wacom drivers, remove conflicting pre-installed components
dnf5 install -y --allowerasing \
	kernel-surface \
	iptsd \
	libwacom-surface \
	libwacom-surface-data

# Enable services
systemctl enable podman.socket

#Enable iptsd
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/iptsd.service \
		/etc/systemd/system/multi-user.target.wants/iptsd.service || true


# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

