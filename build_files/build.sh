#!/bin/bash

set -ouex pipefail


### Disable broken third-party repos during build
if [ -f /etc/yum.repos.d/negativo17-multimedia.repo ]; then
	dnf5 config-manager --set-disabled negativo17-multimedia || true
fi


### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1



# this installs a package from fedora repos
dnf5 install -y tmux 


# Enable services
systemctl enable podman.socket
systemctl enable surface-kernel-install.service

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

