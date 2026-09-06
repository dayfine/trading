# Next-session priorities — 2026-09-07 (written overnight 2026-09-06, ~04:40 PT)

Supersedes `next-session-priorities-2026-09-06.md`. Items 1 and 2 of that doc are
MERGED; item 3 (per-state stop width) is the next build; item 4 (combined surface) follows.

## What landed overnight (2026-09-05 → 06)

- **#2672 delisting guards — PR #2686, squash 1b7295cae.** Three default-off knobs
  (R1/R2): `entry_max_bar_age_days` (entry recency; the DTV stale-bar entry),
  `stale_exit_without_prior_bar` (realise a held position whose symbol has no prior bar
  within `Snapshot_bar_source`'s 60-day lookback — the zombie the armed
  `stale_exit_after_days` cannot see), `stub_print_max_ratio` (terminal stub-print
  truncation via `Snapshot_runtime.Stub_tail`, shared by the simulator bar source and
  every strategy read). Root causes: `memory/project_delisting_guards_2672` — the
  `active_through` marker is populated on NO warehouse (EODHD parser leaves it None;
  zero manifest entries), so the guards key on the series' own last bar. Two rework
  iterations (tests the body over-claimed; `size_is` identity pins; the no-lookahead-edge
  docstring narrowed: a genuine terminal collapse below the ratio is truncated like a
  stub — a known cost; the `stale_force_exit` label does not reach `exit_trigger`, #2687).
- **Breadth-direction macro state — PR #2685, squash 2732ef957.** New
  `Weinstein_types.breadth_state = Bullish_breadth | Neutral_breadth | Deteriorating |
  Recovering | Bearish_breadth` with projections to/from the untouched `market_trend`;
  `Breadth_direction` config nested in `Macro.config` (`enabled` default false; 45% /
  5 pts / 5 pts / 8% / 4 weeks); committed daily series
  `trading/test_data/breadth/synthetic_breadth_daily.csv` (2000-01-03..2026-08-17, per-year
  PIT top-3000, 150d MA, 52-week NH/NL) + `Breadth_bars` / `Breadth_series_cache` (PIT
  cutoff); `breadth_state` on the cascade audit and `macro_trend.sexp` (`[@sexp.default]`).
  With the defaults the state reads Deteriorating 2020-02-28/03-06/03-13 and Recovering
  2020-04-09/17/24/30 (pinned with `elements_are`). Book: the antecedent is Ch. 3's weekly
  percentage-of-bullish-charts gauge read by direction (tier-3 write-back
  `weinstein-book-reference.md` §2.8); ours is an adaptation (% above the 150d MA).
  **Design consequence to carry into item 3:** rule 1 short-circuits on a Bearish trend, so
  `Recovering` can never be observed while the three-state trend is Bearish.
- **Paired re-run** `dev/experiments/delisting-guards-rerun-2026-09-06/` (build 3113f751e,
  behaviour-identical to merged main): 5y-2019 off = 16.79% / 179 / maxDD 22.04
  (reproduces the recorded null digit-for-digit); on = 52.12% / 169 / maxDD 21.65 — **the
  whole +35pp is STMP** (−$175.8k stop at $0.04 → +$1.5k series-end exit at $329.61);
  everything else is path divergence. 26y: `dg-26y-off` reproduced the record digit-for-digit (302.65% / 723 / Sharpe 0.40 /
  maxDD 36.26, 06:23 PT — no build drift); `dg-26y-on` = **139.81% / 714 / Sharpe 0.29 / maxDD 38.39** — 163pp BELOW the record.
  Dissected: the stub-tail guard trims every dying symbol's terminal run, so the universe
  differs on 1,292 of 1,335 screens from 2000-01-14 (gap up to 22 symbols); the first
  top-20 pick that flips is 2003-06-12 (BKNG→SEIC) and the paths never reconverge (457/720 shared; off-only +$1.25M vs on-only +$35k). **Path lottery, not
  a guard cost** — the STMP correction is exact in the shared trade. **Do NOT re-base on
  this arm.** Options: salts 1–2 of both arms (4 × 2.8 h), or arm guards 1+2 only in the
  record convention and keep STMP as a known phantom until guard 3 has salts.
- Issue #2687 filed (blank `exit_trigger` on every stale force-exit; pre-existing — 7 blank
  rows in the record). Breadth scripts/series committed under
  `dev/experiments/yearly-trade-review-2026-09-04/breadth/`.

## The sequence (unchanged from 09-06, items 1–2 done)

### 1. Close out #2672: record re-base + interleaved-series sibling

- The record is NOT re-based (see above). USER DECISION: (a) salts 1–2 of the 26y pair
  (`chain.sh` takes a salt loop trivially; ~11 h, overnight, no agents alongside), or (b)
  arm guards 1+2 only in the record convention (no universe perturbation) and re-run once.
  Either way the writeup must read the guard effect as a distribution, never one pair.
- Decide whether to arm the three guards in the record convention (a spec change, not a
  default flip) — user decision; the evidence is the paired 26y pair.
- File the sibling issue for the interleaved class (CLE/ICT/ABK/MEL/MVL/AGR; 66 symbols
  with ≥20 flagged bars in `arc-rerun-2026-09-01/results/splice-scan.csv`): per-bar
  plausibility gate at fill time, or a warehouse-build drop of splice-flagged symbols.
- #2687: thread the label into the synthetic trade's `exit_trigger`.

### 2. Per-state stop width (09-06 item 3) — now buildable

`initial_stop_buffer` becomes a map over the five breadth states (default: the current
single value in every slot — R1). The fallback-stop builder reads
`Macro.result.breadth_state` at entry (`Cascade_trace` already carries `macro`). First map:
Bullish/Recovering → 12% (0.9167), Neutral → 8–10%, Deteriorating/Bearish → the book's
4–6% band (1.0). Keep `stop_update_cadence Weekly` separate. Remember Recovering ∧ Bearish
are exclusive by construction (above).

### 3. Combined surface (09-06 item 4)

Cells: 2019–23 on `snap_top3000_2019`, 2000–04 on `snap_top3000_dedup_v5thin_adj`, salts
0–2, plus 26y; comparator = the re-based record AND the 12%-weekly arm; pre-registered rule
as in the stop surface. Owed regardless: `sw26y-w12-D`, the 26y drawdown-window dissection,
a ledger entry, paired goldens for every knob that moves.

## Standing results (fixed basis) — pending re-base

- Record: 302.65% / 723 / Sharpe 0.40 / maxDD 36.26 (`record-rebase-2026-09-03`) with
  ~$741k phantom stub-print loss inside it.
- 12%-weekly 26y arm: 761.20% / 862 / 0.58 / 29.73 (`sw26y-w12-W-s0`).
- 2019–23 null on the 2019-vintage warehouse: 16.79% / 179 / maxDD 22.04 (re-confirmed 09-06).

## Ops notes (new)

- **Session rate limit hit at 23:20 PT** (subagents on opus; reset 01:30) — two QC agents
  died mid-review; re-dispatched after reset. Plan QC waves before 23:00 or after 01:30.
- **feat-agent stall mode confirmed 3×** (backgrounded dune → agent ends turn "I'll report
  once the build finishes"): finish from the dispatcher — commit AND push in the same
  command, then verify from the pushed ref; the harness reaps the worktree within minutes
  of TaskStop (`feedback_harness_reaps_uncommitted_agent_worktrees`, third instance).
- **PR body Test plan comes from the diff, not the brief** (`feedback_pr_body_test_plan_from_diff`)
  — #2686 lost a rework iteration to two advertised-but-absent tests.
- `goldens-affected` fires on a NEW default-off knob whose docstring cites an armed knob
  (related-via); resolution = one paired golden run on the PR build + `paired-run-done`
  label (REST: `gh api -X POST repos/.../issues/N/labels`; `gh pr edit` hits the scope error).
- Chain memory guard works: `ABORT (pre-dg-26y-off): 2941MiB free < 4096` while a rework
  agent was linking; relaunch resumes via RESULT-skip.
- Container `/tmp` holds ~4.7k test temp entries after cleanup (root-owned ones survive);
  `du -sm /tmp/*` hits "Argument list too long" — use `find -maxdepth 1`.
- `/loop` in this repo = session-local, never the cloud question (`feedback_loop_no_cloud_question`).

## Do not

- Do not quote the 5y-2019 on-arm 52.12% as a lever — it is one phantom loss removed.
- Do not flip `initial_stop_buffer`, `stop_update_cadence`, any macro threshold, or the
  three #2672 guards' defaults on the evidence so far.
- Do not describe the Weekly cadence as weekly-close evaluation.
