# Runbook — paperclip-hq

## 1. VM (one time)

- Hetzner CX32 / DigitalOcean 4 GB (~$8–24/mo). Agents run builds (`next build`) inside the
  container — 4 GB RAM minimum, 8 GB if more than two agents run at once. Ubuntu 24.04.
- Install Docker: `curl -fsSL https://get.docker.com | sh`
- Firewall: inbound 22, 80, 443 only (DigitalOcean cloud firewall `paperclip-web`).
- DNS: A record `agents.ops-rihal.com` → VM IP, Cloudflare proxy **off** (Caddy needs it for the cert).
- On DigitalOcean this whole section is automated by `infra/cloud-init.sh`.

## 2. Credentials (one time)

- **Anthropic:** console → new workspace "paperclip" → API key → Limits → monthly cap.
- **GitHub:** Settings → Developer settings → Fine-grained tokens → **only `paperclip-hq`** to start →
  Contents RW + Pull requests RW. Expiry 90 days (calendar a rotation).
- Add both **in the Paperclip UI** (agent → adapter environment / secrets) rather than `.env`: rotate
  them there without a redeploy. `.env` holds only `BETTER_AUTH_SECRET` and `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET` (`openssl rand -hex 32` each, generated once, backed up with the data). Never commit `.env`.

## 3. Start

```bash
./scripts/bootstrap.sh
```

First start takes ~5 minutes (image pull). Open https://agents.ops-rihal.com, pass the gate, and create your account
immediately (first account = instance admin).

## 4. First company (in the UI)

1. Create a company; mission e.g. "Maintain and improve the paperclip-hq deploy repo."
2. Add a **CEO** agent (adapter: Claude Code / `claude_local`), small budget, heartbeat 60 min.
3. Add 1–2 **engineer** agents (Claude Code) on https://github.com/Tariq-AlNuaimi/paperclip-hq,
   with the branch rule from GUARDRAILS.md in their instructions. Add more repos later, one at a time.
4. Set the company budget below the Anthropic cap. Turn approvals on.
5. Create one small, well-scoped task first and watch a full heartbeat end to end before adding more.

## Day 2

| Task | Command |
|---|---|
| Status | `cd upstream/docker && docker compose -f docker-compose.quickstart.yml -f docker-compose.override.yml ps` |
| Logs | same, `logs -f --tail 200` |
| Backup (nightly cron) | `0 3 * * * cd ~/paperclip-hq && ./scripts/backup.sh` — then copy `backups/` off the box |
| Upgrade | Pause agents → `./scripts/upgrade.sh <sha>` |
| Rollback | `tar -xzf backups/<file>` over `data/` → `./scripts/upgrade.sh $(cat .paperclip-ref.prev)` |
| Rotate keys | edit `.env` → `./scripts/bootstrap.sh` |

## Troubleshooting

- **Adapter check says Claude prerequisites missing** — `ANTHROPIC_API_KEY` not set on the agent in the UI
  (adapter environment / secrets).
- **Agents can't push** — PAT expired or missing repo; `GH_TOKEN` is read by `gh`/git in the container.
  For pushes over HTTPS, configure the credential helper in the agent instructions:
  `git config --global credential.helper '!f() { echo username=x-access-token; echo password=$GH_TOKEN; }; f'`.
- **Push rejected by `npm run ship` / review gate** — working as intended; the agent must fix and
  re-run, not bypass.
- **UI unreachable** — `docker compose ... logs caddy` (cert issuance needs DNS + ports 80/443).
- **Uptime monitor** — DigitalOcean checks `https://agents.ops-rihal.com/healthz` (Caddy answers it without the gate; the gated `/` returns 401, which monitors count as down).
- **Rotate the gate password** — write a new bcrypt hash to `caddy/basic_auth.hash`, re-run `bootstrap.sh`.
