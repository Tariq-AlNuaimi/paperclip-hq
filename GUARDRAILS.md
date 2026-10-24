# Guardrails — read before giving agents a repo

Paperclip agents are Claude Code processes running unattended with your API key and a GitHub token.
These rules keep a bad heartbeat cheap.

## Hard limits (set outside Paperclip — agents can't change them)

| Limit | Where | Setting |
|---|---|---|
| Spend | Anthropic console → dedicated workspace → Limits | Monthly cap, start at **$50** |
| Repo reach | GitHub fine-grained PAT | Only listed repos; **Contents RW, Pull requests RW**; no Admin, no Workflows, no Secrets |
| Merge | Each target repo → branch protection on `main` | Require a PR + 1 approval; agents' token can't approve its own PRs |
| Network exposure | Caddy basic-auth gate + Paperclip login; app on 127.0.0.1 | `bootstrap.sh` refuses to start without the gate hash |

## Soft limits (set in Paperclip's UI)

- **Company budget** below the Anthropic cap (e.g. $40 of $50) so Paperclip pauses agents before the
  key starts failing mid-task.
- **Per-agent budgets** — the CEO/planner agent gets the smallest; it delegates.
- **Approvals on** for: hiring new agents, goal changes, anything that opens a PR.
- **Heartbeats** no faster than every 30 min to start. Each one is a paid Claude Code run.

## Working on fullstack-vibe-template forks

Those repos already gate every push: `.husky/pre-push → npm run ship` plus the `Reviewed:` review gate
and gitleaks. That's a feature — agents can't push red or unreviewed code to them. Agents must:

1. Work on a branch (`agent/<task-id>`), never `main`.
2. Run `npm run ship` and `/review` before pushing — the hooks enforce it anyway.
3. Open a PR; a human merges.

Never give an agent a task that says "use --no-verify" or "skip the gate"; that skips gitleaks too.

## Kill switch

1. Paperclip UI → pause the company (stops all heartbeats).
2. If that's not enough: `docker compose ... stop` on the VM (see RUNBOOK).
3. If a key may be leaked: revoke `ANTHROPIC_API_KEY` in the console and the PAT in GitHub — both
   take effect immediately — then rotate in `.env` and re-run `bootstrap.sh`.
