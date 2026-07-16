#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/lenovo-generic.sh
source /tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/hardware-security.sh
purplefin_apply_hardware_security lenovo-generic
