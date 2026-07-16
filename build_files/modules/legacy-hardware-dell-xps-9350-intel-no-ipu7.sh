#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/dell-xps-9350-intel-no-ipu7.sh
purplefin_apply_hardware_security dell-xps-9350-intel-no-ipu7
