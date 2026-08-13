# Next-session priorities — 2026-08-14 (afternoon)

**Supersedes** `next-session-priorities-2026-08-14.md` (written 02:00; a full
day's work has landed since). Read this one.

## Start here

1. `gh run list --branch main --workflow CI --limit 1` — main was green at 14:40.
2. **`sh dev/scripts/pr_gate_status.sh`** — new this session. Prints every open
   PR's gate state and its ONE next action. Run it at session start and after
   every agent wave; do not re-derive gate state by hand.

## Two governance findings that outrank the feature work

### 1. An ops fast-path merged a FEATURE to main with zero reviews

PR **#2309**, titled `ops(budget): record 2026-08-13-31700595897 ($32.1972)` and
described as *"additive observational data only"*, actually contained the entire
P0.1 `.mli`-linter feature diff (`linter_file_length.sh`, its test, `dune`). It
merged with **0 reviews**, bypassing both QC gates. #2308 — the branch meant to
carry that code through the gates — became a byte-identical no-op and has been
closed.

The bypass came from the **label**, not a human decision, so it recurs. Before
merging any `ops/*` / budget / daily PR:

```sh
gh pr view <N> --json files --jq '[.files[].path]'
```

Anything outside `dev/{budget,daily,health,audit,status}/` is not an ops record.
Full record: `project_ops_fastpath_bypassed_qc`.

**Owed follow-up (new PR against main, the code is already there):** the linter's
header justifies tracking `.ml` and `.mli` populations separately — the guard
against one population's `@large-module` markers subsidising the other's 11%
opt-out cap — and **no fixture exercises it**. Fixture D1 deliberately avoids the
case. Add one where declared-large `.mli` exceeds 11% while `.ml` stays clean.

### 2. The seeded RETIRE list is not a worklist — every remaining row fails Rule 4

Merged as #2312. After #2307 found `enable_continuation_buys` was seeded from a
**misattributed verdict** (the cited entry armed `enable_scale_in`, already spent
on #2299), the same screen was run against the rest:

- `stage3_exit_margin_pct` + `stage3_reentry_cooldown_weeks` — the memory says the
  plumbing *"stays on main … Do NOT flip the production default"*.
- `macro_bearish` pair — **no ledger entry exists at all**; memory says axis.
- `vol_scaled_stop` pair — **no ledger entry**; a *screen*, not WF-CV.

The seeding collapsed Rule 4's two REJECT shapes into one. **Treat every
remaining row as presumed ineligible until it passes its own screen.** Two of the
four rows that did ship carried the same contradiction and needed the
classification recorded first. The program is "screen a row and expect no", not
"work the list".

## The strategy result: nearfloor is a promotion CANDIDATE

26y × top-3000, **3 salts per arm** (`dev/experiments/nearfloor-26y-salts-2026-08-13/`):

| metric | core | nearfloor | separated? |
|---|---|---|---|
| return | 315.0 | 454.0 | **no** — overlap 337–398; 8/9 pairwise, p≈0.10 one-sided |
| trades | 1151 | 976 | yes, zero overlap |
| win rate | 33.2 | 40.1 | yes |
| **maxDD** | 38.8 | **29.0** | yes |
| holding | 47.2 | 73.9 | yes |

**The risk signature separates cleanly at both 302/6y and 26y.** The **return
direction is scale-dependent and unresolved**: core wins 9/9 with complete
separation at 302/6y; nearfloor leads +139pp (8/9) at 26y but the ranges overlap.
That is non-establishment, not refutation.

**Retracted this session:** "nearfloor collapses path-variance" (shipped in #2288)
is 302/6y-specific — at 26y its spread is 204.3 vs core's 132.5, i.e. *wider*.

**Next step if pursued:** a `Variant_matrix` axis under WF-CV per
`promotion-confirmation.md` (≥3 cells, macro-regime diversity, DSR). **Not** more
salts of the same window — that cannot fix n=3-per-arm power. A 3-salt sp500/5y
run would separately disambiguate breadth from window length in the retraction.

⚠ **The P2 concentration table in the 08-14 doc is still suspect** — its baseline
row is the same cell measured here with a ~3× understated spread. Re-run both arms
with ≥3 salts before treating 0.20 as a candidate.

## P0.2 shipped the mechanism (PR #2311)

`trading/backtest/scenarios/candidate_universe/` — capture at `min_grade=F`,
collect every symbol that ever became a candidate, pin exactly those. 17,751
candidates → 3,707 grade-F rows → 291 symbols.

**Acceptance test passed in its strongest form**: re-running the same spec against
the 291-symbol fixture produced **byte-identical** `actual.sexp`, `trades.csv`,
`equity_curve.csv`, `trade_audit.sexp`, `macro_trend.sexp`, `open_positions.csv`.

**What remains — this validated the mechanism, not the payoff.** 302 → 291 saves
3 seconds. The payoff run is a **top-3000 capture pinning a few hundred symbols**,
which is what makes per-mechanism scenarios affordable. That is the obvious next
task, and it is a long single-scenario run, so give it the container alone.

After that: the per-mechanism scenarios themselves, with sanity-bound assertions
(trade count within ~2× baseline, holding period not collapsing, return not
sign-flipping — F5 trips all three). Split screening-side (nearfloor, freshness)
from execution-side (TTL, volume-confirm-at-fill).

## Carried forward

- **#18** `stop_initial_distance_pct` empty on ~57% of trades.csv rows — still
  blocks stop-width analysis.
- **P0.1** `.mli` linter is on main (un-QC'd, see above); the fixture gap is owed.
- **#4**, **#12**, **#14**, **#8**, **#15**, **#16**, **#10**, **#11**, **#6**.

## Operational rules added this session

- `container-capacity-scheduling.md` — a multi-hour backtest and an agent wave are
  **mutually exclusive** (7.75GB container; six agents OOM-killed a 26y run 1h53m
  in, silently). Measure with `docker stats`, **not** per-process RSS: the mmap'd
  snapshot warehouse inflates RSS to ~10GB against a real 2.2–2.4GB footprint.
- `pr-gate-loop.md` + `pr_gate_status.sh` — QC runs on every PR immediately;
  both verdicts must be at the **current tip**.
- Agents stall two ways: the 120s Bash timeout auto-backgrounds dune calls, and
  Monitor notifications never reach a subagent. Pass `timeout: 600000`, and tell
  the agent what you have already verified so it need not run the long command.
- **Verify a QC agent actually posted its review** (`--json reviews | length`) —
  one produced a complete review this session and never posted it.
