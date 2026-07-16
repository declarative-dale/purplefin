#!/usr/bin/env bash
set -euo pipefail

install -D -m 0644 /tmp/purplefin-profile-files/modules/it/manifests/flatpaks.preinstall /usr/share/flatpak/preinstall.d/purplefin-it.preinstall
