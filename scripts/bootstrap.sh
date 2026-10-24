#!/usr/bin/env bash
# Clone Paperclip at PAPERCLIP_REF into ./upstream, build its image, start it on the Tailscale IP.
# Safe to re-run: ./data is kept.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "missing .env (cp .env.example .env)"; exit 1; }
set -a; source .env; set +a

for v in BETTER_AUTH_SECRET PAPERCLIP_TOOL_ACTION_SIGNING_SECRET PAPERCLIP_PUBLIC_URL; do
  [[ -n "${!v:-}" ]] || { echo "refusing to start: $v is empty in .env"; exit 1; }
done
[[ -n "${ANTHROPIC_API_KEY:-}" ]] || echo "WARNING: ANTHROPIC_API_KEY empty: UI runs but Claude Code agents cannot work until you set it and re-run bootstrap.sh"
case "${BIND_ADDRESS:-}" in
  100.*) ;;      # Tailscale CGNAT range: reachable from your tailnet
  127.0.0.1) ;;  # loopback: reach it with an SSH tunnel (ssh -L 3100:localhost:3100 root@<vm>)
  *) echo "refusing to start: BIND_ADDRESS must be 127.0.0.1 or this VM's Tailscale IP (100.x.y.z), got '${BIND_ADDRESS:-}'"; exit 1 ;;
esac

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
echo "Paperclip up at $PAPERCLIP_PUBLIC_URL (tailnet only). First visit: create the admin account."
