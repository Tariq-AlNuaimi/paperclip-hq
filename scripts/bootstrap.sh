#!/usr/bin/env bash
# Run Paperclip's prebuilt image for PAPERCLIP_REF behind Caddy (HTTPS + password gate).
# No source build: upstream's Dockerfile compiles Rust + a 4 GB-heap TS build and OOMs a 4 GB VM.
# Safe to re-run: ./data is kept.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "missing .env (cp .env.example .env)"; exit 1; }
set -a; source .env; set +a

for v in DOMAIN PAPERCLIP_PUBLIC_URL PAPERCLIP_DB_PASSWORD BETTER_AUTH_SECRET PAPERCLIP_TOOL_ACTION_SIGNING_SECRET; do
  [[ -n "${!v:-}" ]] || { echo "refusing to start: $v is empty in .env"; exit 1; }
done
[[ -s caddy/basic_auth.hash ]] || { echo "refusing to start: caddy/basic_auth.hash missing (see .env.example)"; exit 1; }
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || echo "WARNING: ANTHROPIC_API_KEY empty: fine if you set it per agent in the Paperclip UI (adapter environment / secrets)"

# bcrypt hashes contain '$', which compose would interpolate, so the hash goes into the Caddyfile
# itself rather than through an env var.
sed "s|__BASIC_AUTH_HASH__|$(cat caddy/basic_auth.hash)|" caddy/Caddyfile > caddy/Caddyfile.rendered

[[ "$PAPERCLIP_REF" =~ ^[0-9a-f]{40}$ ]] || { echo "refusing to start: PAPERCLIP_REF must be a full commit SHA"; exit 1; }
# Image and compose file come from the same commit, so they can't drift apart.
mkdir -p upstream/docker data pgdata
curl -fsSL -o upstream/docker/docker-compose.quickstart.yml \
  "https://raw.githubusercontent.com/paperclipai/paperclip/$PAPERCLIP_REF/docker/docker-compose.quickstart.yml"
echo "$PAPERCLIP_REF" > .paperclip-ref
cp docker-compose.override.yml upstream/docker/docker-compose.override.yml
cp .env upstream/docker/.env

echo "PAPERCLIP_IMAGE=ghcr.io/paperclipai/paperclip:sha-${PAPERCLIP_REF:0:7}" >> upstream/docker/.env
echo "running paperclip image sha-${PAPERCLIP_REF:0:7}"

cd upstream/docker
docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml pull
docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml up -d
docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml ps
echo "Paperclip up at $PAPERCLIP_PUBLIC_URL. First visit: pass the gate, then create the admin account."
