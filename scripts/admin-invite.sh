#!/usr/bin/env bash
# Print a one-time invite URL for the FIRST instance admin.
# In authenticated+public mode Paperclip disables claiming admin from the browser ("waiting on its
# first admin"), so the invite has to come from the host. Run on the VM:
#   cd /opt/paperclip-hq && ./scripts/admin-invite.sh
# Open the printed URL, create your account, done. The URL is single-use; don't share it.
# Docker deployments have no Paperclip config.json, so a throwaway one is written inside the
# container from the container's own env (DATABASE_URL, PAPERCLIP_PUBLIC_URL) for the CLI to read.
set -euo pipefail
cd "$(dirname "$0")/../upstream/docker"

docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml exec -T -u node paperclip sh -c '
node -e "require(\"fs\").writeFileSync(\"/tmp/pc-cli-config.json\", JSON.stringify({
  \$meta: { version: 1, updatedAt: new Date().toISOString(), source: \"configure\" },
  logging: { mode: \"file\" },
  server: { deploymentMode: \"authenticated\", exposure: \"public\" },
  auth: { baseUrlMode: \"explicit\", publicBaseUrl: process.env.PAPERCLIP_PUBLIC_URL },
  database: { mode: \"postgres\", connectionString: process.env.DATABASE_URL },
}))"
cd /tmp && npx -y paperclipai auth bootstrap-ceo -c /tmp/pc-cli-config.json --base-url "$PAPERCLIP_PUBLIC_URL" 2>&1 | grep -v "npm warn"
rm -f /tmp/pc-cli-config.json
'
