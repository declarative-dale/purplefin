#!/usr/bin/env bash
set -euo pipefail

# Intentional scaffold: do not ship unvalidated Framework-specific tuning.
source /tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/hardware-security.sh
purplefin_apply_hardware_security framework-laptop
