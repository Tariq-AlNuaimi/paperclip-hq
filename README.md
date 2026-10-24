# paperclip-hq

Self-hosted [Paperclip](https://github.com/paperclipai/paperclip) (MIT) — an org chart, task board,
budgets and approvals for a team of **Claude Code** agents that work on our repos (starting with
`fullstack-vibe-template` forks).

This repo is a **deploy wrapper**, not a fork: it pins an upstream commit, runs Paperclip's own Docker
image build, and keeps it **private** — reachable only through an SSH tunnel (or Tailscale), never the public internet.

```
paperclip-hq/
├── .env.example          # pinned ref + API keys → copy to .env (never commit)
├── docker-compose.override.yml  # binds to the Tailscale IP only, restart policy
├── scripts/bootstrap.sh  # clone pinned upstream, build, start
├── scripts/upgrade.sh    # move the pin, rebuild, keep data
├── scripts/backup.sh     # tar the data dir (embedded Postgres, secrets key, workspaces)
├── GUARDRAILS.md         # what agents may and may not do — read before giving them a repo
└── RUNBOOK.md            # VM + Tailscale setup, first company, day-2 ops
```

## What it does — and what it doesn't

- **Does:** runs its own `claude` CLI processes (the `claude_local` adapter) on this VM, on a schedule
  ("heartbeats"), against tasks you assign in its UI, within a monthly budget, with approvals.
- **Doesn't:** drive claude.ai cloud sessions. Each agent is a Claude Code process inside the
  container, authenticated with `ANTHROPIC_API_KEY`, billed to that key.

## Access

```bash
ssh -L 3100:localhost:3100 root@<droplet-ip>   # then open http://localhost:3100
```

## Quick start (on a fresh VM — see RUNBOOK)

```bash
git clone git@github.com:Tariq-AlNuaimi/paperclip-hq.git && cd paperclip-hq
cp .env.example .env    # API key, Tailscale IP + URL, two `openssl rand -hex 32` secrets
./scripts/bootstrap.sh
```

Open `PAPERCLIP_PUBLIC_URL` from any device on your tailnet and create the admin account.

## Decisions

| Choice | Why |
|---|---|
| Authenticated mode **and** loopback/Tailscale-only | Upstream's Docker quickstart already requires login (`PAPERCLIP_DEPLOYMENT_MODE=authenticated`, private exposure). We add a network layer: whoever reaches this UI controls agents holding your API key and GitHub token, so the port never touches the public internet. |
| Anthropic **API key** with a spend limit, not a Claude subscription login | Unattended automation; Paperclip's budget numbers then match a real bill you can cap in the Anthropic console. |
| Pinned upstream commit | Upstream only publishes nightly/canary tags and moves fast; we upgrade deliberately. |
| Fine-grained GitHub token, PRs only | Agents propose; humans merge. See GUARDRAILS.md. |
