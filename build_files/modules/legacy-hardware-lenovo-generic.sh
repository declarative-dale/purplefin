#!/usr/bin/env bash
set -euo pipefail

/tmp/purplefin-build/profiles/lenovo-generic.sh
purplefin_apply_hardware_security lenovo-generic
