#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/tmp/purplefin-build/profiles/lib/role-common.sh
source /tmp/purplefin-build/profiles/lib/role-common.sh

echo ":: Applying development devops component"
/tmp/purplefin-build/profiles/components/devops.sh

purplefin_apply_role_overlay development
