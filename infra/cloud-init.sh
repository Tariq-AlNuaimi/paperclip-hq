#!/bin/bash
# DigitalOcean user-data for a fresh Ubuntu 24.04 droplet. the provisioner appends this repo as
# a base64 tarball (REPO_TARBALL). Secrets are generated HERE, on the droplet, so they never leave
# it. The UI listens on 127.0.0.1 only: ssh -L 3100:localhost:3100 root@<droplet-ip>
set -euo pipefail  # no -x: it would log the generated secrets
exec > >(tee -a /var/log/paperclip-bootstrap.log) 2>&1

if [[ ! -f /swapfile ]]; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

command -v docker || curl -fsSL https://get.docker.com | sh

mkdir -p /opt && cd /opt
echo "$REPO_TARBALL" | base64 -d | tar -xz
cd /opt/paperclip-hq

if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s|^BETTER_AUTH_SECRET=.*|BETTER_AUTH_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|^PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=.*|PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|^PAPERCLIP_PUBLIC_URL=.*|PAPERCLIP_PUBLIC_URL=http://localhost:3100|" .env
fi
chmod 600 .env

./scripts/bootstrap.sh

echo '30 3 * * * root cd /opt/paperclip-hq && ./scripts/backup.sh >> /var/log/paperclip-backup.log 2>&1' > /etc/cron.d/paperclip-backup
echo "BOOTSTRAP DONE" > /var/log/paperclip-bootstrap.done
