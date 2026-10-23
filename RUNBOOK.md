# Runbook — paperclip-hq

## 1. VM (one time)

- Hetzner CX32 / DigitalOcean 4 GB (~$8–24/mo). Agents run builds (`next build`) inside the
  container — 4 GB RAM minimum, 8 GB if more than two agents run at once. Ubuntu 24.04.
- Install Docker: `curl -fsSL https://get.docker.com | sh`
- Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
- Firewall: allow **nothing** inbound on the public interface (Tailscale SSH replaces port 22):
  `sudo ufw default deny incoming && sudo ufw allow in on tailscale0 && sudo ufw enable`
- `tailscale ip -4` → put it in `.env` as `BIND_ADDRESS`.

## 2. Credentials (one time)

- **Anthropic:** console → new workspace "paperclip" → API key → Limits → monthly cap.
- **GitHub:** Settings → Developer settings → Fine-grained tokens → only the target repos →
  Contents RW + Pull requests RW. Expiry 90 days (calendar a rotation).
- Put both in `.env`, plus `BETTER_AUTH_SECRET` and `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET` (`openssl rand -hex 32` each, generated once, backed up with the data). Never commit `.env`.

## 3. Start

```bash
./scripts/bootstrap.sh
```

First build takes several minutes. Open `http://<tailscale-name>:3100` from your laptop/phone on the
tailnet.

## 4. First company (in the UI)

1. Create a company; mission e.g. "Ship internal-tool prototypes on fullstack-vibe-template."
2. Add a **CEO** agent (adapter: Claude Code / `claude_local`), small budget, heartbeat 60 min.
3. Add 1–2 **engineer** agents (Claude Code), each with the repo URL and branch rule from
   GUARDRAILS.md in its instructions.
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

- **Adapter check says Claude prerequisites missing** — `ANTHROPIC_API_KEY` not reaching the container:
  `docker compose ... exec paperclip printenv ANTHROPIC_API_KEY | cut -c1-8`.
- **Agents can't push** — PAT expired or missing repo; `GH_TOKEN` is read by `gh`/git in the container.
  For pushes over HTTPS, configure the credential helper in the agent instructions:
  `git config --global credential.helper '!f() { echo username=x-access-token; echo password=$GH_TOKEN; }; f'`.
- **Push rejected by `npm run ship` / review gate** — working as intended; the agent must fix and
  re-run, not bypass.
- **UI unreachable** — is your device on the tailnet? `tailscale status`. The port is deliberately not
  on the public IP.
