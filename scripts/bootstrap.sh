#!/usr/bin/env bash
# Clone Paperclip at PAPERCLIP_REF into ./upstream, build its image, start it behind Caddy
# (HTTPS + password gate). Safe to re-run: ./data is kept.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "missing .env (cp .env.example .env)"; exit 1; }
set -a; source .env; set +a

for v in DOMAIN PAPERCLIP_PUBLIC_URL BETTER_AUTH_SECRET PAPERCLIP_TOOL_ACTION_SIGNING_SECRET; do
  [[ -n "${!v:-}" ]] || { echo "refusing to start: $v is empty in .env"; exit 1; }
done
[[ -s caddy/basic_auth.hash ]] || { echo "refusing to start: caddy/basic_auth.hash missing (see .env.example)"; exit 1; }
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || echo "WARNING: ANTHROPIC_API_KEY empty: UI runs but Claude Code agents cannot work until you set it and re-run bootstrap.sh"

# bcrypt hashes contain '$', which compose would interpolate, so the hash goes into the Caddyfile
# itself rather than through an env var.
sed "s|__BASIC_AUTH_HASH__|$(cat caddy/basic_auth.hash)|" caddy/Caddyfile > caddy/Caddyfile.rendered

if [[ ! -d upstream/.git ]]; then
  git clone https://github.com/paperclipai/paperclip.git upstream
fi
git -C upstream fetch -q origin
git -C upstream checkout -q "$PAPERCLIP_REF"
git -C upstream rev-parse HEAD > .paperclip-ref
echo "building paperclip @ $(cat .paperclip-ref)"

mkdir -p data
cp docker-compose.override.yml upstream/docker/docker-compose.override.yml
cp .env upstream/docker/.env

cd upstream/docker
docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml up -d --build
docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml ps
echo "Paperclip up at $PAPERCLIP_PUBLIC_URL. First visit: pass the gate, then create the admin account."
