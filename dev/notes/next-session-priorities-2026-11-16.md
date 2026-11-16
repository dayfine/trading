# Next-session priorities — 2026-11-16 (supersedes 2026-11-15 EOD)

Both stop-width arms are read, and neither flags: msd-12 −0.27 and msd-18 −0.58 median D_end, so the record's 15 %
sits at the peak. The third arm (fbt-05, the failed-breakout gate) is running at a new HEAD, which also gives the
first baseline-drift read. The 13 missed weekly-pick Fridays are backfilled on the record config. Open issues: 9.

## 1. Merged since the 11-15 EOD handoff (#3644)

| PR | what |
|---|---|
| #3646 | ops-data agent doc: single-dash fetch flags; bucket parallel fetches by shard (#3645) |
| #3647 | weekly picks backfill, 13 Fridays 08-21 → 11-13, at 89a08b1fe on `dev/weekly-picks/record-config-overrides.sexp`; public price-free summaries, full records private (trading-results afd8105, c01e99a) |
| #3648 | msd-18 lane results, flag none |
| #3649 | lane: V12 follows the arm's stop gate (validator `-config`); queue gains fbt-05 and cap-40 |

## 2. Observatory

- **msd-18 (#3648):** median D_end −0.580 (seeds −0.16 … −0.75), 57 % negative years but only 2 seeds at 60 %, so
  HARM fails. Losses are in bull years (−0.455; bear −0.063); +6.3 entries a year, +1.65 positions held; drawdown
  +0.8 pp by median but +7.1 and +9.2 pp on two seeds, Ulcer higher on all five. Price-band slice: arm-only entries
  are 9–10 % ≤ $14 against S's 11–12 % (not a cheaper mix), but in count the arm adds 32–39 cheap entries and drops
  21–24 of S's, net +9 to +17; the cheap names it loses are S's monsters (ADMA 2023-12, APPS 2020-06). 2008 flat.
  V7 rises with the gate width (S 32–39, msd-18 115–129, msd-12 0): note it in any later stop-gate read.
- **Reading across the two:** a width curve that peaks at the record (`project_stop_width_curve_not_linear`), with
  neither side steady enough per year to flag. The low-price trait does not live at this gate: the larger loss for
  cheap names is `No_structural_stop`.
- **fbt-05 lane running:** cloud session `cse_013VUubhSyNUkuKqaRnGUNNh`, LANE_SHA ecd77c760, launched 12:02Z 11-16.
  New HEAD, so S k0–k4 re-run (tripwire against the record md5, drift pair S@ecd77c760 vs S@3c367cca7) plus fbt-05
  k0–k4: 10 cells, expected to publish ~01:00–02:00Z 11-17. Then the mechanical read, a results PR (qc-results), and
  cap-40 at the same SHA (reuses S, ~7 h).
- **Results-branch mechanics:** the repo deletes head branches on merge, so each lane recreates
  `observatory/lane-results`. GitHub's update-branch cannot apply the union merge in `.gitattributes`: merge main
  into the branch locally with git (a scratch worktree), keep the branch's queue rows, push.

## 3. Weekly picks

- Backfilled (#3647). Macro Bullish to 10-23, Neutral 10-30, **Bearish 11-06 and 11-13 with no longs** (the index
  stage alone decides it on this path).
- **Decided (user, 11-16):** picks stay on the record config without the live 5 % failed-breakout gate, though 10–19
  of each Friday's 20 longs sit > 5 % under their breakout (the buy-stop fills only on a re-break). The gate goes
  through the observatory (fbt-05, running).
- **Next Friday (11-20):** refresh bars from 11-13 (stale set), rebuild inventory, eligible list and warehouse, then
  generate. The recipe and scripts are in the gitignored `dev/data/ops-fetch-2026-11-16/` and
  `dev/data/weekly-picks-backfill-2026-11/` (rebuild the exes first). The weekly cadence still has no owner.
- **Local state to know:** the refreshed `data/inventory.sexp` is git-tracked. The main checkout's working copy is a
  scratch change holding it ("never push"); a `jj new` there reverts it on disk. Do PR work in separate workspaces.

## 4. Queue

1. fbt-05 read and results PR; then launch cap-40 at ecd77c760.
2. P2c curves page (private, data from trading-results).
3. Weekly picks for 11-20, and an owner for the cadence.
4. #3645 (manifest race + `build_snapshots` output dir), `env/cloud`, `ready-for-agent`.
5. Optional issue: the picks validator's 7 `stop_side` errors are all extended rows sized to 0 shares.
6. Carried: pack render blank-slice check; #3613; TRW-wein-742 stop timing; entry-timing README estimand note;
   orchestrator CI pre-flight fallback; D1 td-full shadowing; #3587; SPY refresh; 38 near-tightening stops;
   dangling-doc linter; #3578; `pr_gate_status` 3000-file sentinel; #3610 "sub-top-1000" wording.

## 5. Decisions waiting (raise at 11:00 PT)

- **Weekly picks cadence owner.** (A, recommended) a local weekly slot after Friday's close: refresh, generate,
  publish (data is local); (B) leave it manual.
- **Host headroom (optional, carried):** delete `.sweep-output` entries older than 30 days (~4 GB); quit Docker
  Desktop when nothing local needs it. Swap was 15.5 / 16 GB on 11-15 evening, from the Arduino build load.

## 6. Lessons

- **Share is not count.** "The wider gate does not let in more cheap names" was true as a share and false as a count;
  qc-results caught it. A slice that argues about tickets states both.
- **A body-only rework still needs a tip-moving commit**: NEEDS_REWORK then APPROVED at one SHA reads as conflicting
  in `pr_gate_status.sh`. Push an empty commit, re-run CI, carry the verdict forward.
- **`jj new` in the main checkout reverts tracked local data.** Keep the main checkout's working copy as the scratch
  change and commit from workspaces.
- **The cheap cloud wait works:** msd-18's session woke 4 times in 5.5 h (a bounded background wait plus one 120-min
  fallback) against ~4 an hour for msd-12.
