#!/usr/bin/env bash
set -euo pipefail

source /tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/hardware-security.sh
purplefin_apply_hardware_security generic-x86_64
