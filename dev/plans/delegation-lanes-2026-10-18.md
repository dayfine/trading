# Delegation lanes, quota budget and visibility (2026-10-18)

User direction, 2026-10-18: keep a cost tracker and adjust the work size daily ("it hurts when we don't have quota
for days"); find work for Codex and look at a Codex cloud environment like our Claude cloud one, and at other
options (Cursor and others); with more lanes, still know what is happening where, and reserve quota for the most
important task, which is managing.

Trigger: the fresh-eyes forward pass used up the weekly plan quota in under a day (2026-10-14/15). The GHA
orchestrator run of 10-17 failed and every session was blocked until the 10-18 reset.

## 1. The daily quota budget

- `sh dev/scripts/quota_status.sh` reads the five-hour and seven-day utilization from one ~$0.02 Haiku probe and logs
  it to `~/.claude-quota/log.csv`. It prints the burn rate, the projected use at reset, and today's allowance
  for project work: `(1 − used − reserve) / days left`.
- **Management reserve: 15 % of the week**, held for dispatching, reading results, QC and merges. Project work
  (feature agents, batch readers, analysts) spends only the allowance.
- **Session start:** run it after the main-CI check and size the session from the `suggest:` line:
  - MANAGEMENT ONLY;
  - SMALL: one agent, cheaper models;
  - NORMAL: up to 3 agents;
  - LARGE: room for a batch or an Opus wave.
- **Batch jobs** call `quota_status.sh --guard 0.85` (or lower) before each unit and stop on exit 3. They never
  wait out a usage limit (`.claude/skills/batch-model-run/SKILL.md`).
- **Daily record:** the weekly usage review (`perf-review-weekly.md` §Usage review) reads the log alongside the
  `dev/budget/` token files.

## 2. Lanes

| lane | runs on | quota | good for | status |
|---|---|---|---|---|
| local Claude session | this Mac + container | Claude plan | managing, local data, long runs, verdict reads | in use |
| Claude cloud session | Anthropic cloud env (`env/cloud` label) | Claude plan | self-contained harness/code with no local data | in use |
| Codex CLI (local) | this Mac, read-only sandbox | ChatGPT plan | advisory PR review (`codex_review.sh`) | in use |
| **Codex cloud** | chatgpt.com/codex environment | ChatGPT plan, separate from Claude | `agent/codex` issues: small, mechanical, well-specified code/doc changes that open a PR | **spike next** |
| GitHub Copilot coding agent | GitHub Actions | Copilot plan ($10–39/mo, token credits) | issue → draft PR, best GitHub-native visibility | option |
| Claude API key in GHA | our CI image | pay as you go, independent of the plan | QC waves and `env/cloud` work when the plan is short; Batch API (50 % off) for bulk image reads | **dropped 10-18** (#3325): about 20–30× less work per dollar than the plan; the next plan tier (Max 5x → 20x) is the capacity lever |
| Cursor cloud agents | Cursor VMs | API-rate billing after the plan credit | — | skip: no flat-rate advantage; Dockerfile builds from GitHub triggers reported flaky |
| Jules | Google cloud | free tier / Google AI plan | same lane as Codex (`agent/jules`), A/B against it for 2–3 weeks | **trial after Codex** (#3324, folded from #3329) |

The research behind this table (sources, unverified points) is in the PR description that adds this file.

### Codex cloud spike (≈ 1 h of user setup, $0 extra on the current ChatGPT plan)

1. The user connects GitHub at chatgpt.com/codex, then creates an environment for `dayfine/trading` (base image
   `universal`) and pastes `.codex/cloud-setup.sh` as its setup script. This is an account action, so the user
   does it.
2. Success criteria: setup completes (record the cold time); `dune build @fmt && dune build && dune runtest
   trading/orders` passes in a task; the task opens a PR.
3. Agent-phase internet stays off; secrets are not needed for build/test.
4. From then on: `codex cloud exec --env <id> "<brief>"` from this machine, `codex cloud list` in
   `where_is_work.sh`.

### Work for Codex now (all `agent/codex`, small, PR-sized, no local data)

- #3263: NYSE A-D fixture calendar check, scoped to rows from 2000 onward (comment of 10-18).
- #3140 part 1: review-pack missed-winners card (host-only HTML/awk). Part 2 follows.
- File-length and function-length splits like #3307 (cleanup PRs; the linters name them).
- Record touch-ups queued in the handoff: #3265's six wording nits, the score-threshold `run.sh` header,
  `reader.sh:41` mkdir-before-check, `rulecard.md:224` quote nit.

Every Codex PR still goes through qc-structural and qc-behavioral, which are Claude reviews (`cross-agent-review.md`).
QC therefore spends Claude quota and sits inside the management reserve.

## 3. Visibility: GitHub is the ledger

- **Labels:** `author/codex`, `author/cursor` and `author/copilot` go on PRs. `env/cloud` and `agent/codex` go on
  issues handed to a lane.
- **Branch prefixes:** `codex/`, `cursor/`, `copilot/`. Claude cloud sessions keep their default branch names.
- **One screen:** `sh dev/scripts/where_is_work.sh [--quota]` lists:
  - open PRs by lane, with the gate next-action;
  - issues handed to each lane;
  - long jobs on the host and in the container;
  - Codex cloud tasks;
  - the last orchestrator and perf runs.
- **When:** at session start and after each agent wave.
- **Branches:** finished branches are deleted at merge (repo setting, enabled 2026-10-18). A weekly workflow
  (`prune-branches-weekly.yml`, `dev/scripts/prune_remote_branches.sh`) deletes branches whose PR closed more than
  7 days ago. A branch with no PR is never deleted automatically.

## 4. Decisions for the user

1. **Codex cloud spike** (above). Recommended. Needs the user's ChatGPT/GitHub connection.
2. ~~A Claude API key lane in GHA~~ **Dropped (user, 10-18, #3325 closed).** A review costs $0.6–0.9 (structural, Haiku) or
   $4–5 (behavioral, Opus) at API rates, against about 200 structural reviews a month; $20–40 buys a small fraction of
   them and frees about 1–4 % of a week. Move up a plan tier instead. Extra accounts to get around limits: no (terms).
   Async loop on GitHub: board #3330 (`turn/*` labels, 3 h refresh), hand-offs by `@codex` / `@jules` comments.
3. **Copilot coding agent:** optional, $39/month, if the Codex spike fails on the OCaml setup.
4. **Cursor:** not recommended for this workload.

## 5. Codex lanes after the cloud-environment finding (decision 2026-10-18)

The Codex CLI here is on ChatGPT **Plus**, workspace **Personal**, and `codex cloud exec` reports *"no cloud
environments are available for this workspace"*. Four `ccarenv_…` IDs were tried, and none is a Codex Cloud
environment. `@codex` mentions on GitHub get *"create an environment for this repo"* (#3324).

**Lane A: local Codex as a separately charged subagent (in use).**
- The dispatcher runs `codex exec` in a worktree under the repo, with a written brief, under AGENTS.md's local rules.
- It is deterministic: start, exit code and diff are visible before any PR exists.
- The writing costs Codex's quota; the review costs ours.
- Its plan usage can be read from the `rate_limits` line in `~/.codex/sessions/**/rollout-*.jsonl` (5 h and weekly
  `used_percent`).
- It shares the container, so it doesn't build beside a long backtest.
- First task: #3263.

**Lane B: a scheduled Codex task in the personal cloud (options; not enabled).**
Codex's Scheduled feature could run a pull loop every few hours, with one unit of work per run:
1. fix NEEDS_REWORK on `author/codex` PRs;
2. do a real merge of main into conflicting PRs;
3. claim the oldest `agent/codex` + `ready-for-agent` issue while fewer than 3 Codex PRs are open.

A one-line run log would go to #3330. A scheduled task has nobody to click Create PR, so it needs its own GitHub
access. The options:

| option | environment access | what it can do | risk |
|---|---|---|---|
| **B1. write token** | package managers + `api.github.com`/`github.com`; a fine-grained PAT as a secret (`dayfine/trading` only; contents, PRs, issues read/write; no admin, workflows or secrets; 30–90 day expiry) | the full loop: push branches, open PRs, comment | Contents write can technically merge a green PR. AGENTS.md forbids it and the events would show it, but it widens what an internet-facing agent holds. Reverses the "no token" policy in `.codex/README.md` |
| **B2. read-only token** | the same hosts, PAT read-only | reads issues and reviews and proposes diffs; the dispatcher applies them locally | Low. Every change still passes through a local step |
| **B3. none (current)** | package managers only | nothing scheduled | None. Lane A carries Codex work |

**Decision (user, 2026-10-18): B3 now.**
- Revisit B1 once Lane A has delivered clean PRs: first-pass QC approvals, no corrective rounds.
- B2 is the fallback if a scheduled loop is wanted before then.
- A first enablement of B1 records here: the token's scope and expiry, who holds it, and that `.codex/README.md`'s
  network policy changed. The pull-loop prompt was drafted on 10-18 and gets added when B1 is chosen.

**Jules** (Lane C, #3324): mention-driven. First trial #3333: correct content, then 4 replies claiming work that
hadn't landed; rebuilt by the dispatcher as #3337. Rules since then: AGENTS.md §Jules (#3336), and after 2
corrective rounds the dispatcher finishes the task.
