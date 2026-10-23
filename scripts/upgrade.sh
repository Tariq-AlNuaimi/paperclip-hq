#!/usr/bin/env bash
# Usage: scripts/upgrade.sh <commit-sha>
# Backs up ./data, moves the pin, rebuilds. Pause agents in the UI first.
set -euo pipefail
cd "$(dirname "$0")/.."
new="${1:?usage: upgrade.sh <commit-sha>}"

./scripts/backup.sh
sed -i.bak "s/^PAPERCLIP_REF=.*/PAPERCLIP_REF=$new/" .env && rm -f .env.bak
./scripts/bootstrap.sh
echo "Upgraded to $new. Rollback: scripts/upgrade.sh $(sed -n 1p .paperclip-ref.prev 2>/dev/null || echo '<previous sha>') + restore backup."
