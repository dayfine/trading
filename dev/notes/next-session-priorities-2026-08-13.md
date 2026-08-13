# Next-session priorities — 2026-08-13

**Supersedes** `next-session-priorities-2026-08-12.md`. That file's corrections
(the armed-golden env-var mistake, the retracted "partial fix" claim) are
already folded in and need no re-reading; this file carries everything still
open.

## P0 — two queued programs (user-directed 2026-08-12)

### 1. The `.mli` file-length blind spot

**`linter_file_length.sh` has never checked a single `.mli` file.** Its scan is

```sh
find "$TRADING_DIR" ... -path "*/lib/*.ml" ...
```

and `*/lib/*.ml` does not match `*.mli` — the path ends in `i`. There is **no
entry in `linter_exceptions.conf`** because none was ever needed. This is not
"exception then runaway"; the rule simply never applied, so `.mli` size has been
unbounded since day one. That is why the config surface reached ~1,700 lines
without anyone tripping a gate.

If the same 300 soft / 500 hard limits were applied to `lib/*.mli` today:

```
over HARD 500: 4        over SOFT 300: 14
  1659  weinstein_strategy_config.mli   (3.3x the hard limit)
  1256  weinstein_strategy.mli          (2.5x)
   534  trade_audit.mli
   531  screener.mli
```

**Sequencing matters and is the whole difficulty.** Turning the check on now
makes main red with no path to green. Per `.claude/rules/code-health-discipline.md`
the answer is extraction, never a limit bump or an `@large-module` marker — so:

1. Land the remaining retirements (below); they are what shrinks the config
   surface.
2. Re-measure. If `weinstein_strategy_config.mli` is still over 500, the residue
   is a genuine extraction — split the config surface by concern, not a marker.
3. **Then** extend the linter to `lib/*.mli` as the closing move, so the gap
   cannot silently reopen.

Treat this as the last step of the retirement program rather than a separate
task.

### 2. Integration tests / small focused scenarios (carried task #19)

The gap is unchanged and is the thing that would have caught both of the last
two defects: every mechanism goes **unit test → 43-hour ladder**, with nothing
in between. F5 is the proof — its unit tests were correct and comprehensive and
could not catch a 3x candidate explosion.

**What exists today (do not mistake it for coverage):** `smoke/` holds 5
*perf-tier fixtures*, not mechanism assertions; `backtest/scenarios/test/` has 9
files testing runner *plumbing* (fixtures root, universe files, actual.sexp
shape, isolation). The only thing shipped against the gap is PR #2291, the
StopLimit-armed golden — one hole, not a program.

**User's design guidance (2026-08-12), to build to:**

- A smaller universe is fine **if it discards the majority of symbols that would
  never be screened in the narrow window**. Do this mechanically, not by
  guesswork: run the window once with all-eligible capture on, collect every
  symbol that ever became a candidate, emit that set as the fixture universe.
  This is the **shared prerequisite for both designs below** — build it first.
- If it works properly inside defined boundaries — **time, resources, and input
  bar-data size** — that is the best outcome: one end-to-end scenario per
  mechanism.
- **Otherwise it is fine to test screening and trading separately** (screening =
  given fixed bars, which candidates and in what order; trading = given fixed
  transitions, what orders and fills).

Practical note: the split is genuinely *better* for some mechanisms regardless.
TTL and volume-confirm-at-fill are execution-side; nearfloor and freshness are
screening-side. Split those; keep end-to-end only where a mechanism spans both.

**Assertion style: sanity bounds, not pinned values** — armed trade count within
~2x baseline, holding period not collapsing, return not sign-flipping. F5 trips
all three (3,145 vs 1,136 trades; 47.8d → 8.4d; −47.6%), which is the proof the
design works.

Most of the harness already exists: the 24-cell 500/5y matrix
(`dev/experiments/ladder-v4-small-deterministic-2026-08-12/`) runs ~4 min a cell
deterministically, and `TRADING_PATH_SEED_SALT` (#2293) supplies error bars.

## P1 — finish the retirement program (14 of 17 rows open)

**#2284 early_admission and #2286 cash_reserve are MERGED** (all three gates).
#2283 harvest_rotate had structural APPROVED with behavioral still running at
session end.
Effect so far is small — ~85 lines off a ~1,700-line file; the big rows are
still ahead (`continuation`, `scale_in`).

Remaining: 9 seeded-ready (`stage3_exit_margin_pct`, `enable_continuation_buys`
+ config, `enable_scale_in` + config, the `macro_bearish` pair, the
`vol_scaled_stop` pair) and 5 needing classification first (late_stage2 tighten,
stage2_ma_hold, dawn-leverage family, long-margin family, `catastrophic_stop_pct`).

**Run this check before every removal** (added to the inventory 2026-08-12 after
it caught a wrong row):

```sh
git grep -n '<flag> *=' -- 'trading/**/*.ml' | grep -v /test/ | grep -v 'sexp.default'
```

Anything beyond the `default_config` assignment is a live consumer. `trigger_on_weekly_close`
was listed RETIRE but is **live production code** (`Stop_thread` arms it for the
weekly picks report, because that path replays weekly bars). **No golden catches
this class** — goldens exercise the backtest path only.

### Ledger ambiguity that will bite the next retirement

The `cash_reserve_pct` ledger entry contains **both** "envelope program FULLY
closed both directions" / "do NOT re-sweep standalone" **and** the literal
phrase *"cash_reserve_pct stays a searchable axis"* — which is the
keep-as-axis REJECT shape that Rule 4 says is NOT retirement-eligible. RETIRE
was still the right call (the inventory row is the later, authoritative triage,
and the protection role was reassigned to the barbell), but **check the ledger
prose for this contradiction before the next removal** and record the
classification explicitly rather than inferring it.

### Small cleanups owed (from QC advisories; deliberately not fixed post-approval)

- `make_get_close_array`'s docstring in `test_stage.ml` says it "returns the
  same value as the MA at every offset" — now inaccurate for its callers, since
  the repointed Stage-2 MA-hold tests deliberately pass *different* arrays for
  `get_ma` and `get_close` (that is the point of those tests). Assertions are
  unchanged and correct; only the comment misdescribes it. From #2284's
  behavioral review; not fixed because editing the branch after APPROVED would
  invalidate the reviewed SHA.
- A leftover `_none` suffix on a renamed test in the same file.
- `entry_walk.ml:155` still says "partition the (reserve-reduced) cash budget" —
  code-side residue from #2286; sweep it in the next retirement PR.
- `test_short_sleeve_default_crowds_out_shorts` asserts only `Short = 0`, which
  would pass even if `spendable` were wrongly zeroed. One-line fix: add a
  `Long = 3` field assertion.
- `Stage.config` lacks `[@@allow_extra_fields]`, so an archived out-of-repo
  sweep spec still carrying `early_admission_ma_period` now fails to parse.
  Inherent to Rule 4 and accepted — recorded so it is not a surprise.
- **Unverified claim to check:** #2283's structural agent reported the test
  runner "blocked by a pre-existing dune configuration issue on main". My own
  runs on `trading/backtest/test` show only the known `Sys_error` failures from
  the missing local `data/` tree. Either it misdiagnosed those, or there is
  something real. Confirm before trusting a "tests pass" claim on that target.

## P2 — the return-gap program

`project_record_gap_is_concentration` has the full decomposition. Headline: the
record's ~9x lead is AXTI (one trade, 84% of its realized PnL, needs a 57% stop)
**plus** a 2.2x seeded 2000-2004 by running **4.9 concurrent positions to our
10.6**. On shared trades pnl ratio ≈ quantity ratio — we do not pick or exit
worse, we buy fewer shares.

**First concentration result (302/6y, 3 salts each) — promising and separated:**

| `max_position_pct_long` | mean | range | trades | maxDD | ret/DD |
|---|---|---|---|---|---|
| 0.14 (baseline) | 45.6 | 6.6 | 288 | 19.1 | 2.39 |
| **0.20** | **61.6** | 9.0 | 235 | 22.7 | **2.71** |
| 0.28 | 43.7 | 7.8 | 211 | 31.0 | 1.41 |

0.20's worst draw (56.8) beats the baseline's best (48.1) — separated. 0.28 is
not (overlapping ranges) and wrecks drawdown. Inverted-U.

Next: narrow the peak between 0.17-0.24, then test at 26y with salts. Note this
is the first lever found by tracing a mechanism rather than by search.

## Machine state / in-flight

**Chain** (`/tmp/chain_26y_v2.log`, worktree `.claude/worktrees/v4-fixed` pinned
at the salt commit): cells 00 and 09 x 3 salts at 26y on the fixed+salt build.

- cell 00 salt 0 = **281.71** (2h17m)
- cell 00 salt 1 = **397.95** (4h07m — slowed by QC-agent contention)
- **A 116pp spread between two path draws of the same config**, corroborating
  the 278pp null's order of magnitude. This is the honest 26y error bar.
- salt 2 and the three cell-09 runs were still going at session end. Collect
  with `cat /tmp/chain_26y_v2.log`.

Ladder-v4 sweep was killed at 19/24 by user direction (Stage-B deltas were
unreadable against the null). **19 cells preserved** at
`.sweep-output/ladder-v4-artifacts-2026-08-12/` (294M).

## Carried forward, unchanged

- **#18** `stop_initial_distance_pct` empty on ~57% of trades.csv rows. This is
  now **blocking analysis**, not just untidy — it made the record-vs-cell07
  stop-width comparison unusable (record 100% populated, ours 43%).
- **#4** position_id join for audit (ticket age capped at ~1 week).
- **#12** DSR best-of-N = 24, not 13.
- **#14** base-extent anchor. **#8** blind-judge first run. **#15**, **#16**,
  **#10**, **#11**, **#6**.
- **1998 start date** (user question 2026-08-12): the sweep starts at 2000
  because it uses `top-3000-2000.sexp`, a PIT composition snapshot taken *at*
  2000. Going earlier means dropping breadth — the deepest universe available is
  `broad-1000-30y.sexp` (1000 symbols, data from <=1996). It is a
  breadth-vs-history trade, not a free extension, and breadth is the known lever.
  Worth revisiting since 1998 would add the dot-com *top*, not just the bust.
- **Universe staleness caveat**: `top-3000-2000` is survivorship-clean at the
  start but cannot include anything listed after 2000. Fine for relative
  comparisons (every cell shares it); the absolute +343.9% is not tradeable.

## Open PRs at session end

All CI-green. **None is docs-only** (all have non-`.md` files), so all need the
full three gates. See the session's final message for which cleared QC.
