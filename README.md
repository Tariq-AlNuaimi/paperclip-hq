# paperclip-hq

Self-hosted [Paperclip](https://github.com/paperclipai/paperclip) (MIT) — an org chart, task board,
budgets and approvals for a team of **Claude Code** agents that work on our repos (starting with
`fullstack-vibe-template` forks).

This repo is a **deploy wrapper**, not a fork: it pins an upstream commit, runs that commit's prebuilt Paperclip
image (plus Postgres), and serves it at **https://agents.ops-rihal.com** behind Caddy (HTTPS) with a password gate in
front of Paperclip's own login.

```
paperclip-hq/
├── .env.example          # pinned ref + API keys → copy to .env (never commit)
├── caddy/Caddyfile       # HTTPS + basic-auth gate (hash filled in at bootstrap)
├── docker-compose.override.yml  # app on loopback, Caddy public, exposure=public
├── infra/cloud-init.sh   # DigitalOcean first-boot script
├── scripts/bootstrap.sh  # fetch pinned compose file, pull image, start
├── scripts/upgrade.sh    # move the pin, pull that image, keep data
├── scripts/admin-invite.sh  # print the one-time first-admin invite link
├── scripts/backup.sh     # tar data/ + pgdata/ (Postgres, secrets key, workspaces)
├── GUARDRAILS.md         # what agents may and may not do — read before giving them a repo
└── RUNBOOK.md            # VM setup, first company, day-2 ops
```

## What it does — and what it doesn't

- **Does:** runs its own `claude` CLI processes (the `claude_local` adapter) on this VM, on a schedule
  ("heartbeats"), against tasks you assign in its UI, within a monthly budget, with approvals.
- **Doesn't:** drive claude.ai cloud sessions. Each agent is a Claude Code process inside the
  container, authenticated with `ANTHROPIC_API_KEY`, billed to that key.

## Access

https://agents.ops-rihal.com → browser password prompt (gate) → Paperclip login.
The first admin is created from an invite link printed on the server (public mode disables browser
self-promotion): `cd /opt/paperclip-hq && ./scripts/admin-invite.sh`, then open the link.

## Quick start (on a fresh VM — see RUNBOOK)

```bash
git clone git@github.com:Tariq-AlNuaimi/paperclip-hq.git && cd paperclip-hq
cp .env.example .env    # DOMAIN, URL, API key, two `openssl rand -hex 32` secrets
# put a bcrypt hash of the gate password in caddy/basic_auth.hash (see .env.example)
./scripts/bootstrap.sh
```

Open `PAPERCLIP_PUBLIC_URL`, pass the gate, create the admin account.

## Decisions

| Choice | Why |
|---|---|
| Public URL, **two** locks | Paperclip runs `authenticated` + `public` (login required) and listens on loopback; Caddy adds HTTPS and a basic-auth gate. Whoever gets in controls agents holding your API key and GitHub token, so the login endpoints themselves sit behind the gate. Upgrade path: Cloudflare Access (email OTP) once enabled on the account. |
| Anthropic **API key** with a spend limit, not a Claude subscription login | Unattended automation; Paperclip's budget numbers then match a real bill you can cap in the Anthropic console. |
| Pinned upstream commit | Upstream only publishes nightly/canary tags and moves fast; we upgrade deliberately. |
| Fine-grained GitHub token, PRs only | Agents propose; humans merge. See GUARDRAILS.md. |
