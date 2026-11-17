# Next-session priorities — 2026-11-17 (supersedes 2026-11-16)

The observatory has its first flag, and the read found the arm was mis-wired. fbt-05 (the old live picks gate,
`failed_breakout_tolerance_pct 0.05`) flagged HARM at −1.95 log, but the gate compares an adjusted close with a raw
breakout high, so on history it filters on future splits and dividends (#3659). cap-40 is running at the same commit.
The weekly picks now have an owner (a local Saturday slot) and a one-command runner. Ground rules unchanged: backtests
in the cloud, local container for QC and smokes, feat agents build + fmt locally and CI runs tests.

## 1. Merged since the 11-16 handoff (#3650)

| PR | what |
|---|---|
| #3653 | OCaml price-free public picks summary (`public_picks_summary`), replacing the backfill's perl; byte-identical below the header on all 13 backfill Fridays |
| #3654 | `dev/weekly-picks/weekly.sh [--dry-run] <friday>`: refresh → inventory → eligible → warehouse → generate/validate/render → stage (private to `$TR`, public `-picks.md`), resumable; dry-run check, 26 assertions (rework 1 added the bucket, tripwire and `fetch_buckets.sh` pins) |
| #3658 | fbt-05 lane results + results-analyst read `reads/fbt-05.md` (qc-results rework 1 on the PR body's share claim) |
| #3660 | `weekly_picks_dry_run_check.sh` pins that `weekly.sh` calls `bucket_shards` and `check_public_price_free` on code lines (26 → 28 assertions) |

User decisions at 11:03 PT 11-16: weekly picks owner = **local weekly slot** (a local session each Saturday after
Friday's close); host cleanup = delete `.sweep-output` entries older than 30 days (done: 4.4 → 1.1 GB, disk 46 GiB
free). Docker stays up.

## 2. fbt-05 in one paragraph

All validity gates passed (tripwire md5 0928cfe4, V6 5/5, live 5/5, drift-none S@ecd77c760 = S@3c367cca7). Surface row 3:
median D_end −1.945 (seeds −1.59..−2.46), 5/5 seeds 60 %+ negative years, step max 0.08 → HARM. The analyst read
(public `reads/fbt-05.md`, private appendix trading-results 7af6135) finds the estimand invalid: `screener_admission.ml`
compares the adjusted `current_close` (`snapshot_bar_views.ml:79`) with a raw `breakout_price` (`:81`), so the arm kept
0 of S's 659 trades in later forward-splitters and 0 of 1,270 with an adjusted/raw factor < 0.85. The basis-only lost
trades alone (−1.82..−2.14 per seed) are about D_end's size and three quarters of the record contribution the arm
loses, partly refilled. Two channels a clean gate would share are negative in 5/5 seeds but cannot be sized net here:
deeper-rank buys in bear/reopen windows (the bear brake released, #3621/#3631) and record fills lost to cash. No
disjoint-window pre-registration. An ELI 2014-05 bar defect fakes a one-day ×2.35 NAV (V20), so the surface's
`d_maxdd_pp` +39.5 is about +26 without it. Decision A (picks without the gate) stands: in live use the comparison is
consistent. The sibling sites with the same expression (`entry_freshness` under `Range_top_breakout`, `continuation`)
are off the record's path.

## 3. In flight

- **cap-40 lane**: cloud session `cse_013VUubevLLdNQpfJ95Gs2Xq` (routine `trig_01EGdsscqsgyTNNLHwbG7h5T`), LANE_SHA
  ecd77c760, launched 00:39Z 11-17, reuses S from trading-results; 5 cells, expected ~07:15Z. Then the mechanical read
  and a results PR (qc-results). **#3658 merged and deleted `observatory/lane-results`**, so cap-40's publish recreates
  it from ca5ea8f: merge main into it locally before review (as with msd-18). The brief makes a post-restart relaunch
  re-run the dry run first and stop if it picks any arm but cap-40 (with the branch gone, HEAD's queue at ecd77c760 says
  fbt-05 pending). If it stopped that way, relaunch cap-40 at the current main HEAD instead (re-runs S, ~12 h).
  The fbt-05 read predicts cap-40's loss sits in Neutral/Bearish weeks of 2000–02, 2008, 2022–23, with no bull-week
  bleed; read it for entries/positions in those windows, Neutral-week D, cash-rejected fills, and MMYT 2023 / APPS 2020
  / BGO 2003.
- **#3661, the #3659 fix** (`feat/failed-breakout-one-basis`, tip 1ff196d5a): new field
  `Stock_analysis.t.current_raw_close` (adjusted close / that week's split factor); the gate reads it at all three
  sites (admission, candidate eval, watchlist); `current_close` stays adjusted for `friday_selection.ml`. Later-split
  fixture through `Stock_analysis.analyze`, registry row 3659 `fixed`. Next: CI → qc-structural → qc-behavioral →
  merge; then the [after-merge] sibling audit. (The weekly.sh pins dispatched with it merged as #3660.)

## 4. Queue

1. **cap-40 read and results PR** (above).
2. **First real weekly picks run, Sat 11-21, as-of 11-20**: `sh dev/weekly-picks/weekly.sh 2026-11-20` from a jj
   workspace with `SYSVER=<short sha>` (README "Weekly cadence"); it rewrites the tracked `data/inventory.sexp` in the
   data checkout (the main checkout's never-push scratch change). Publish: trading-results commit + push, docs PR for
   the public `-picks.md`. A symbol never fetched before needs ops-data first.
3. **#3659** (ready-for-agent): fix the gate to one basis with a later-split fixture + registry row, or retire the dial;
   then the host-only sibling audit (rt-freshness, continuation verdicts by later-split status). See §5.
4. **weekly.sh guard pin** (qc-behavioral #3660 non-blocking): #3660 pins the two call sites, but flipping
   `[ "$DRY" = 1 ] ||` to `&&` before `check_public_price_free` stays green; pin that exact text too (one line).
5. **Observatory hygiene** (fbt-05 read §5): basis partition in admission-arm reads; `obs_read.sh` DD/Ulcer guard
   against a one-day NAV round trip or a non-V6 invariant failure (V20); a review pack for every flagged arm (RV1).
   The ELI 2014-05 interleaved bars belong to the data-defect backlog.
6. **Next arms**: the funnel order continues with the ranking dials low; a price-comparing dial must pass the
   basis-mix check first (`project_axis_observatory_gate_funnel`).
7. **P2c curves page**: private artifact of all arms' D(t), data from trading-results only.
8. Carried: pack render blank-slice check; #3613; TRW-wein-742 stop timing; entry-timing README estimand note;
   orchestrator CI pre-flight fallback; D1 td-full shadowing; #3587; SPY refresh; 38 near-tightening stops;
   dangling-doc linter; #3578; `pr_gate_status` 3000-file sentinel; #3610 "sub-top-1000" wording; #3645.

## 5. Decisions

- **Quota (user, 18:39 PT 11-16): "we can spend a little bit more".** Seven-day use 57 % with 5.2 days left,
  `quota_status.sh` says NORMAL (up to 3 agents). Work resumed at that size: the two agents in §3, the gates, and
  the cap-40 read. Batch runs still need `--guard`.
- **#3659: fix (recommended) taken** when the user loosened quota without picking; reversible, since the gate is
  default-off. Retire stays open if the user prefers it. Agent on `feat/failed-breakout-one-basis`, raw close at
  offset 0 against the raw breakout, a later-split fixture through the real bar path, a registry row,
  `Refs #3659 -- verify:` the sibling audit.

## 6. Lessons

- **A look-ahead filter applied every week passes the flag rule's shape clause.** It produces a steady slope across
  years and seeds with no dominant step, which is the plan's signature of a real mechanism. Before queueing a dial that
  compares prices, check its inputs share one basis (adjusted `get_close` vs raw highs is the recurring defect, #2982).
- **State shares precisely: a share of what.** "Three quarters of the loss" was wrong; the read said three quarters of
  the record contribution the arm loses, and the basis term alone is about D_end's size. qc-results caught it (R8).
- **Cloud container restarts kill detached lanes.** fbt-05's session was restarted twice in its last batch and resumed
  from finished cells; a relaunch brief must re-check the arm the dry run picks, since merging a results PR deletes the
  branch the queue state is read from.
