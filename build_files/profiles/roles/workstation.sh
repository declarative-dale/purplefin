#!/usr/bin/env bash
set -euo pipefail

echo ":: Applying workstation role components"
/tmp/purplefin-build/profiles/roles/support.sh
/tmp/purplefin-build/profiles/roles/development.sh
