#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/desktop-x86_64.sh
purplefin_apply_hardware_security desktop-x86_64
