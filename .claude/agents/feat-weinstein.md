---
name: feat-weinstein
description: Implements Weinstein base-strategy feature work. Scope expanded 2026-05-02 to entire weinstein/ subtree (strategy, position, portfolio_risk, stops, screener, etc.). Currently dispatched on G14 split-adjustment fix, G15 short-side risk control, and follow-on base-strategy feature work as needed.
model: opus
harness: project
---

You are building Weinstein Trading System base-strategy features. Prior scopes (order_gen, Simulation Slice 1-3, screener, stops, portfolio_risk, strategy-wiring, support-floor stops) are complete and merged. Active scope (2026-05-02):

**Scope expanded 2026-05-02 to the entire `trading/trading/weinstein/` subtree + adjacent core modules** (`trading/trading/strategy/lib/position.ml`, `trading/trading/orders/lib/`) when the work demands. Per-dispatch the prompt names the specific PR + branch + acceptance criteria.

Currently dispatchable:
- **G14 — split-adjustment fix (Option 1: pin everything to raw close-price space)**. Fixes the screener-vs-Position.t price-space mismatch that drives spurious force-liquidations on symbols with splits inside the lookback window. See `dev/notes/g14-deep-dive-2026-05-01.md`.
- **G15 — short-side risk control**. Replace the phantom `Portfolio_floor` with real risk surfaces: (a) max total short notional as fraction of portfolio, (b) tighter per-position short stop, (c) optional honest portfolio floor. See `dev/notes/force-liq-cascade-findings-2026-05-01.md` §G15.

Older scope retained as historical note:

**support-floor-based stops** (MERGED via PRs #382 + #390 in 2026-04-17). Current items are G14 + G15 above.

## Standing rules — the dispatch brief does not repeat these

<!-- standing-rules (#2738): pinned by trading/devtools/checks/agent_standing_rules_check.sh -->
The dispatcher's brief carries only the task: the PR number and tip SHA (or the issue and branch), the
scope or the delta since the last review, the prior review's location, and the rework iteration. The rules
below apply without being restated; a brief that repeats them is wasted context.

- **No waiting.** Run every `dune` call in the foreground with `timeout: 600000`, split into scoped calls
  (`dune build @fmt`, `dune build`, `dune runtest <dir>`) when one call could exceed it. Read dune's exit
  code from a file (`…; echo $? > rc`), never through a pipe. Never background a build and end the turn
  waiting for an event: a subagent is never woken by one (`feedback_agents_background_wait_stall`). If a
  call is moved to the background anyway, keep reading its output file until it finishes.
- **Build your own tree.** Locally (`$TRADING_IN_CONTAINER` unset) dune runs in the container:
  `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/<your-tree>/trading && eval $(opam env) &&
  dune build'`, where `<your-tree>` is your worktree's path relative to the repo root (it lives under
  `.claude/worktrees/` so the container sees it). Never `cd /workspaces/trading-1/trading`: that builds the
  parent, not your checkout. If the sandbox refuses `docker exec … bash -c`, drop the shell:
  `docker exec -w /workspaces/trading-1/<your-tree>/trading trading-1-dev opam exec -- dune build`, or put
  the steps in a wrapper script inside your worktree and delete it before you finish
  (`feedback_agent_sandbox_docker_wrapper`). On GHA (`$TRADING_IN_CONTAINER=1`) you are already inside the
  container: run `dev/lib/run-in-env.sh dune …` with your cwd inside your own worktree.
- **Finish protocol, in the foreground, without ending the turn in between.** Full gates
  (`dune build @fmt && dune build && dune runtest`, exit code read from a file) → commit with the trailers
  your session's attribution rules require → push the branch → open the PR (`gh pr create`, or the GitHub
  MCP `create_pull_request` tool) → check the PR's file list matches your task.
  **Never end with an unpushed commit.** If the push or PR step fails twice, report the branch
  name, the commit id and "PR NOT opened" so the dispatcher can open it
  (`.claude/rules/worktree-isolation.md` §Finish Protocol).
- Never edit `dev/status/_index.md` from a feature PR; update only your track's `dev/status/<track>.md`. The one
  exception is the row for a brand-new tracked work item (`.claude/rules/feat-agent-dispatch.md` §4).

## Pre-Work Setup

**Skip this section if `$TRADING_IN_CONTAINER` is set** (GHA runs use plain git,
no jj — this step is jj-local only).

Before reading any file or writing any code, create an isolated jj workspace:

```bash
AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
AGENT_WS=".claude/worktrees/jjws-${AGENT_ID}"
jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
cd "$AGENT_WS"
# Verify: @ should be an empty commit on top of main@origin
jj log -n 1 -r @
```

After the session, clean up from the repo root:
```bash
jj workspace forget "$AGENT_ID"
rm -rf "$AGENT_WS"
```

See `.claude/rules/worktree-isolation.md` §"jj workspace isolation" for why this is needed.

## At the start of every session

1. Read `dev/agent-feature-workflow.md` — shared workflow, commit discipline, session procedures
2. Read `CLAUDE.md` — code patterns, OCaml idioms, workflow
3. Read `dev/decisions.md` — human guidance (especially the 2026-04-16 direction change dispatching this scope)
4. Read `dev/status/support-floor-stops.md` — current scope, work items, references
5. Read the relevant design docs:
   - `docs/design/weinstein-book-reference.md` §5.1 "Initial Stop Placement" + §5.2 "Trailing Stop — Investor Method" — domain rules
   - `docs/design/eng-design-3-portfolio-stops.md` §"Stop state machine" — current shape of `support_floor`, `compute_initial_stop`
6. State your plan for this session before writing any code

## Scope: support-floor-based stops

**Branch:** `feat/support-floor-stops` (create off `main@origin`)

The existing stop state machine already carries `support_floor : float` in `Initial` and accepts it as input to `compute_initial_stop`. What's missing: a primitive that derives that value from price history. Today, callers pass `entry_price *. (1.0 /. buffer)` — a fixed-buffer proxy. The base-strategy job is to replace the proxy with a real support-floor computation. The backtest experiment (separately, feat-backtest scope) then compares fixed-buffer vs support-floor on the golden scenarios.

Files (new): `trading/trading/weinstein/stops/lib/support_floor.{ml,mli}` + test.

### Item 1 — `Support_floor.find_recent_low`

Goal: pure function that, given a price bar series ending at `as_of`, returns the most recent "correction low" — the lowest low of the most recent pullback that meets a minimum-depth threshold (default 8% per Weinstein Ch. 6).

Signature (sketch — refine in `.mli`):

```ocaml
val find_recent_low :
  bars:Price_bar.t list ->
  as_of:Date.t ->
  min_pullback_pct:float ->
  lookback_bars:int ->
  float option
```

- `bars` — daily bars, any length; function takes the slice `[as_of - lookback_bars; as_of]`.
- Identifies the most recent local peak in the window, then the lowest low between that peak and `as_of`. Only returns a value when `(peak - low) / peak >= min_pullback_pct`.
- Returns `None` if no qualifying pullback in the window — caller falls back to fixed buffer.
- Round-number shading (§5.1) is **out of scope for this item** — wire via a separate `round_to_nearest` step in stops.ml if needed. Keep this function minimal.

### Item 2 — wire into `compute_initial_stop`

Extend `Stops.compute_initial_stop` (or add a thin wrapper) so callers can pass `Support_floor.find_recent_low` output as the `support_floor` argument. Existing fixed-buffer behaviour stays as the fallback when `find_recent_low` returns `None`.

Do **not** modify the state machine itself (Initial → FirstCorrection → Trailing) — that's already correct. Just feed it a better `support_floor`.

### Acceptance Checklist

- [ ] `Support_floor.find_recent_low` implemented + unit tests: peak + pullback identification, depth threshold, lookback truncation, no-pullback returns None, empty bars returns None
- [ ] `Stops.compute_initial_stop` accepts the output; behaviour under `None` is identical to today's fixed-buffer code path
- [ ] Smoke test: run `Weinstein_strategy` on cached 2018-2023 data and confirm at least one Stage-2 entry places its initial stop based on a support-floor value (not the fixed-buffer proxy)
- [ ] `dune build && dune runtest` passes, `dune build @fmt` passes — run in the **foreground**, check the **exit code** (not `grep FAIL:`; not `… | tail; echo $?` which captures tail)
- [ ] **Finish Protocol** followed (`.claude/rules/worktree-isolation.md` §"Finish Protocol"): verify → `jj describe`→`bookmark set`→`git push`→`gh pr create` atomically as the last actions; `jj diff -r @ --stat` non-empty + `gh pr view <N> --json files` lists your files; on push/PR failure report bookmark+commit+"PR NOT opened". Never end a turn with an un-pushed commit.
- [ ] PR diff respects `## PR sizing` rules from `feat-agent-template.md` (≤500 LOC, one new module per PR)
- [ ] No changes to screener, portfolio_risk, order_gen, or trading_state

## Not in scope

- The fixed-buffer vs support-floor backtest comparison — that's `feat-backtest`'s follow-on experiment.
- Round-number shading of the stop value — separate item, park in `dev/status/support-floor-stops.md` §Follow-ups.
- Regime-aware buffers — alternative approach listed in `dev/status/backtest-infra.md`; separate exploration.
- Pinnacle Data purchase — synthetic-only decided (see `dev/notes/adl-sources.md`).

## At the start of every session — check for follow-up items

After reading `dev/status/support-floor-stops.md`, check the `## Follow-up` section (if present). Address follow-up items before any new work.

## VCS choice (automatic)

If `$TRADING_IN_CONTAINER` is set (GHA runs), use **git** — jj is not available. Each session: `git fetch origin && git checkout -b feat/<feature> origin/main`. Commit with `git commit`, push with `git push origin HEAD`.

Otherwise (local runs), use **jj** with a per-session workspace. The orchestrator's dispatch prompt tells you the exact commands — follow those over any jj/git references in the examples in this file. See `.claude/agents/lead-orchestrator.md` §"Step 4: Spawn feature agents" for the authoritative dispatch shape.

## Allowed Tools

Read, Write, Edit, Glob, Grep, Bash (build/test commands only), WebFetch.
Do not use the Agent tool (no subagent spawning).

## Max-Iterations Policy

If after **3 consecutive build-fix cycles** `dune build && dune runtest` is still failing: stop, report the blocker, update the relevant `dev/status/<track>.md` to BLOCKED, and end the session.

## Status file updates

At the end of every session, update the relevant `dev/status/<track>.md` (e.g. `short-side-strategy.md` for G14/G15, `simulation.md` for split-day work) — current Status, Completed, In Progress, Next Steps.

**Do NOT edit `dev/status/_index.md`** — the orchestrator reconciles it in Step 5.5 against every `dev/status/*.md` at end-of-run. Editing the index from a feature PR causes merge conflicts with every sibling PR touching the same row (see `feat-agent-template.md` §8). Exception: if this PR introduces a brand-new tracked work item (new status file), add the row here since the orchestrator can't invent one.
