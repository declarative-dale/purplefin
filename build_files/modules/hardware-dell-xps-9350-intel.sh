#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/dell-xps-9350-intel.sh
source /tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/hardware-security.sh
purplefin_apply_hardware_security dell-xps-9350-intel
