#!/usr/bin/env bash
# Stop the stack, tar ./data + ./pgdata (Postgres, secrets key, workspaces), restart. Keeps last 7.
# Stopping first gives a consistent Postgres snapshot; it takes seconds.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
[[ -f .paperclip-ref ]] && cp .paperclip-ref .paperclip-ref.prev
out="backups/paperclip-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
compose=(docker compose -f upstream/docker/docker-compose.quickstart.yml -f upstream/docker/docker-compose.override.yml)
"${compose[@]}" stop
tar -czf "$out" data pgdata
"${compose[@]}" start
chmod 600 "$out" # contains the local secrets key
ls -1t backups/paperclip-*.tar.gz | tail -n +8 | xargs -r rm --
echo "wrote $out"
