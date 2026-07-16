#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/desktop-x86_64.sh
source /tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/hardware-security.sh
purplefin_apply_hardware_security desktop-x86_64
