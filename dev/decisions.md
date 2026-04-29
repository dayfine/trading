# Decisions & Guidance

**Agents: read this at the start of every session.**
**Lead: summarize new decisions in each daily summary.**

This file is the primary channel for human → agent communication between sessions.
Write answers, decisions, and direction changes here. Agents will pick them up the next morning.

---

## Open Questions

_(None yet — system just initialized.)_

---

## Decisions Log

### Architecture

- Do not modify existing `Portfolio`, `Orders`, or `Position` modules. Build alongside them.
- All thresholds and parameters must live in config, never hardcoded.
- All analysis functions must be pure (same input → same output, no hidden state).
- The Weinstein strategy implements the existing `STRATEGY` module type.

### Development

- Follow TDD workflow from CLAUDE.md: interface first → tests → implementation.
- Mark "Interface stable: YES" in status file as soon as `.mli` is finalized, even before full impl.
- QC approval required before any feature merges to main.
- Merge order: data-layer → portfolio-stops → screener → simulation.

### order_gen — correct design (two prior attempts closed for violating this)

- **Location:** `trading/weinstein/order_gen/` — NOT `analysis/weinstein/order_gen/`
- **Input:** `Position.transition list` from `strategy.on_market_close` — NOT screener candidates
- **Role:** pure formatter only — translates transitions into broker order suggestions; no sizing decisions, no `Position.t` dependency, no `Portfolio_risk` calls
- **Rationale:** sizing decisions are already made by the strategy; order_gen is strategy-agnostic so any strategy using Position.transition gets order formatting for free
- **Reference:** `docs/design/eng-design-3-portfolio-stops.md` §"Order Generation" — see the `.mli` sketch and the decision table at the bottom of that section
- PRs #203 and #214 were both closed for putting order_gen in `analysis/` and making it take screener candidates with sizing logic

---

## Direction Changes

### 2026-04-29 — Split-day broker model: regression — strategy-side `Position.t` not split-adjusted

PR-3 (#664) wired split detection + `Split_event.apply_to_portfolio` into `Simulator.step`, but only adjusted the broker-side `Trading_portfolio.Portfolio.t`. The strategy-side `Position.t String.Map.t` (`t.positions`, exposed to strategies via `Portfolio_view.positions`) was left at pre-split values. On a 4:1 split, `Holding.quantity` stays at 100 while the broker portfolio holds 400 shares; when the strategy emits `TriggerExit` post-split, `Order_generator` reads the stale 100 from `Exiting.quantity` and the engine sells 100 shares against the 400-share broker position, leaving 300 orphan shares. The strategy's `Position.t` transitions to `Closed`, so it never attempts to clear the orphans.

Symptoms on the sp500-2019-2023 baseline rerun: total return -144.5% (vs. expected ~+70% on the post-fix), MaxDD 245.79%, portfolio_value -$17,793 on 2020-08-31 (started from $1M). A long-only strategy cannot go negative without a cash-accounting bug; the orphan-shares + AverageCost-basis-shift mechanics drove this.

Fix: `fix/split-day-broker-model-debug` adds `Simulator._apply_splits_to_positions` (sibling of `_apply_split_events`), called immediately after `_apply_split_events` in `step`. Each split event scales matching strategy positions: `Holding.quantity *= factor`, `Holding.entry_price /= factor`; `Exiting` mirrors on share counts and per-share prices. `Entering` (in-flight order) and `Closed` (historical) pass through unchanged. Test: `trading/trading/simulation/test/test_split_day_stop_exit.ml` (3 tests) — synthetic 4:1 split with a buy-then-trigger-exit strategy. All 3 FAIL on current main, PASS post-fix.

Lesson — PR-3 verification scope was structurally insufficient: `test_split_day_mtm.ml` (3/3 PASS) checks portfolio MtM continuity through a split with a passive buy-and-hold strategy, AND smoke parity goldens (`panel-golden-2019-full`, `tiered-loader-parity`) cover non-split windows. Neither exercises the cross-side consistency between `Portfolio` and `Position.t` on a split day where a stop / signal triggers a post-split exit. Going forward, broker-model PRs that touch position state must include a regression test that combines (a) a split event with (b) an active stop / exit trigger on a post-split bar — verifying that the strategy's view and the broker's view stay in lockstep.

Stop-adjustment audit (out of scope for this minimal fix; flagged for `feat-weinstein` follow-up): The Weinstein strategy's `stop_states` ref carries an absolute stop price ($440 pre-split). Across a 4:1 split that becomes economically equivalent to $110, but the ref is not split-adjusted. After a split, `Weinstein_stops.check_stop_hit` will compare bar.low_price=$124 vs. stop_level=$440 and fire a spurious exit on the first post-split bar. The orphan-shares bug was the load-bearing failure mode; the spurious-trigger bug compounds it. Address in a separate PR scoped to `weinstein_strategy.ml` (which is `feat-weinstein`-owned per `dev/decisions.md` §"Notes for Specific Agents").

### 2026-04-29 — Split-day OHLC: broker model (closes #641, ships PR-1..PR-4)

Split days are **discrete events on the position ledger**, not continuous OHLC adjustments. All consumers (Simulator MtM, engine fills, screener `get_price`, resistance, breakout) read raw OHLC straight from `Daily_price.t`; `adjusted_close` is reserved for back-rolled smoothness on relative-strength, MAs, momentum, and breakout-vs-historical-resistance only. On a split day the position's quantity multiplies by the split factor and per-share cost basis divides — total cost basis preserved exactly, realized P&L unchanged. This matches live brokerage semantics and is the canonical fix for the AAPL 2020-08-31 4:1 phantom 75% MtM drop on `sp500-2019-2023` (the 97.7% MaxDD was the bug, not the strategy).

Closure: PR #641's band-aid (`_split_adjust_bar` rescaling every pre-corporate-action bar) was held indefinitely because dividend back-roll meant every historical day got rescaled, drifting fill prices and dropping sp500 from 134 trades to 30 — un-comparable to baseline. The broker-model redesign was authored as `dev/plans/split-day-ohlc-redesign-2026-04-28.md` and shipped over four PRs: PR-1 (#658) added `Split_detector` primitive; PR-2 (#662) added `Split_event` ledger primitive; PR-3 (#664) wired detector + ledger into `Simulator.step` (raw OHLC paths unchanged); PR-4 (this PR) verified non-split-window goldens stay bit-identical (smoke parity gates 7 / 5 round-trips match pre-#641 main) and resolved the #641 closure trail. The 97.7% phantom MaxDD on sp500 is now expected to drop to ~5% on a local re-run of the canonical scenario; that re-run is deferred to a maintainer-local invocation because GHA cannot supply the 491-symbol sp500 universe data (same blocker as the tier-4 release-gate).

### 2026-04-16 — Reopen feat-weinstein for support-floor-stops + close open escalations

Decisions from the 2026-04-16-run1 orchestrator session (daily PR #375, §Escalations):

- **Support-floor-based stops, cross-track dispatch** — choose **(a)**. Reopen `feat-weinstein` scope for the support-floor-stops primitive in `weinstein/stops/`. Agent definition at `.claude/agents/feat-weinstein.md` rewritten for this scope (`feat/support-floor-stops` branch). Status file at `dev/status/support-floor-stops.md`. Base-strategy-owned; `feat-backtest` picks up the experiment next run once the primitive lands. `dev/status/backtest-infra.md` §Blocked on updated to point at the new status file.

- **GHA container tooling gap** — choose **(2)**. Workflow pre-step runs `jj git init --colocate && jj git fetch` so `jst submit` works from within the orchestrator container. Do not add `gh` CLI to the base image — `jj` + `jst` is the preferred path and aligns with local-dev tooling. Change lands in `.github/workflows/orchestrator.yml`.

- **ADL live source** — **synthetic-only, confirmed.** No EODData registration, no Pinnacle evaluation. Synthetic ADL composed on top of Unicorn in `Ad_bars.load` (already shipped in strategy-wiring #355) is the permanent answer. Drop this from future escalations; update `dev/notes/adl-sources.md` to mark the decision final if it still reads as provisional.

- **Stale remote branches** — pruned: `harness/dispatch-flow-revise`, `deps/opam-weekly`, `docs/backtest-data-followups`, `docs/decisions-update`, `dev/reviews/strategy-wiring-structural`, `dev/reviews/strategy-wiring-behavioral`. All were either already merged or had no open PR. Future orchestrator runs should only list branches with live PRs in §Integration Queue.

### 2026-04-14 — Backtest infrastructure has its own agent + Plan-first dispatch

- **`feat-backtest` agent now owns the backtest-infra track.** Previously
  human-driven. Definition at `.claude/agents/feat-backtest.md`. Status
  file at `dev/status/backtest-infra.md`. Scope: experiments + strategy-
  tuning features (stop-buffer tuning, drawdown circuit breaker,
  per-trade stop logging, segmentation-based stage classifier, universe
  filter, sector-data scrape integration). Distinct from `feat-weinstein`
  (which owns the base strategy code, currently complete).

- **Flagship Immediate item: stop-buffer tuning experiment.** The entire
  #306/#315/#316 infrastructure was built specifically to unblock it.
  See `dev/status/backtest-infra.md` §Next Actions.

- **Plan-first applies to feat-backtest's first deliverable.** Per
  `.claude/agents/lead-orchestrator.md` §Step 3.5 (triggers 1 "first
  deliverable from a new agent" and 4 "experiment design"), the
  orchestrator dispatches the built-in `Plan` subagent to produce
  `dev/plans/stop-buffer-<YYYY-MM-DD>.md` BEFORE dispatching feat-backtest.
  Human reviews the plan PR and merges it; feat-backtest is then
  dispatched on the next run with the approved plan as binding pre-flight
  context.

- **Lead-orchestrator has Plan Mode.** `./dev/run.sh --plan` short-circuits
  Steps 2-6 and emits a dispatch plan to `dev/daily/<DATE>-plan.md`
  without spawning any subagents. Use for dry runs.

- **`dev/run.sh` is now hardened**: pre-flight asserts (`claude` on PATH,
  agent file present, `## Allowed Tools` lists Agent), live event ticker
  via stream-json + jq, heartbeat every 30s. Helpers in `dev/lib/`.

- **Orchestrator daily summary drift is a known issue.** Sections like
  `## Integration Queue` get copied forward from prior dailies rather
  than reconciled against current GH state. Fix tracked in
  `dev/status/harness.md` Follow-up; gated on `gh` auth in the runtime
  environment (see `dev/status/orchestrator-automation.md`).

---

## Notes for Specific Agents

### feat-backtest

- Your first session must check the dispatch prompt for `### Approved plan`.
  If present, treat the referenced `dev/plans/...md` file's §Approach and
  §Out of scope as binding; QC will verify. If absent and the item you're
  about to work on matches a Step 3.5 trigger, **stop and return an
  escalation** instead of implementing.
- Don't modify `weinstein_strategy.ml` or core stop-machine code — build
  alongside, or surface the proposed change in your status file for
  feat-weinstein review.

### lead-orchestrator

- Per §Step 3.5: invoke the `Plan` subagent before dispatching any feat-agent
  whose status file §Completed is empty (e.g. feat-backtest today),
  whose item is tagged `plan_required: true`, has prior closed/rejected
  PR attempts, or is an empirical experiment.
- Plan-mode invocations (`--plan` token in prompt) MUST NOT dispatch
  any subagent. Read state, write `dev/daily/<DATE>-plan.md`, exit.
