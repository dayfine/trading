---
name: project_pit_universe_migration
description: "P0 09-14: migrate the record to a point-in-time top-3000 universe. The 28 yearly top-3000-{1998..2025} PIT lists ALREADY EXIST (May-31 anchor, Mar–May dollar-volume rank, delisted-inclusive); the runner has NO dated membership — the seam is Screener.screen_with_cooldown ?membership_at (today fed only by enable_pi_filter). Plan + decisions D1–D8 in dev/plans/pit-universe-migration-2026-09-14.md (#2808). Union 2000–2025 = 10,008 names; 2,483 real names fetched 09-14."
metadata:
  type: project
  originSessionId: 9c80ae81-e4ff-45bf-a128-8273f65cc237
  modified: 2026-09-14T17:49:37.617Z
---

**State on 2026-09-14 (local session).** User decision 04:45 PT: the 26y record
runs on the year-2000 vintage list held fixed (`top-3000-2000.sexp` = 3,000
names as of 2000-05-31 — say "year-2000 vintage", never "the 2000 list"); the
two vintages share only 1,023 of ~2,980 names, so every level is survivor-
inflated and the next queue item (top-of-funnel) is a membership question.

**What already exists (the handoff was wrong on step 2):**
- `trading/test_data/goldens-custom-universe/composition/top-3000-{1998..2025}.sexp`,
  built by `build_composition_universes_runner` / `Build_from_individuals`:
  anchor YYYY-05-31, rank by avg(close×volume) over Mar-1..May-31, inventory
  filter start ≤ Apr-1 & end ≥ May-31, equity-like only. Delisted-inclusive.
- **No dated membership in the runner**: `universe_path` → `Runner._load_deps`
  → `config.universe : string list`, fixed per run; `snapshot.date` discarded by
  the `Universe_snapshot` bridge; walk-forward/rolling-start copy `universe_path`
  per fold. The 06-05 PIT-goldens plan excluded intra-run rebalancing.
- **The seam**: `Screener.screen_with_cooldown ?membership_at:(string -> Date.t -> bool)`
  rejects before classification; candidate-only (exits iterate the portfolio);
  fed by `Weinstein_strategy_macro._membership_at_callback_of` (PI filter).
  Macro gate + sector RS read indices/ETFs via `_all_runner_symbols`, untouched.
- Bar reader folds a symbol missing from the warehouse to an empty view
  silently — the warehouse must cover the union (D6).

**Decisions (D1–D8, plan §1):** May-31 anchor kept; list dated YYYY-05-31 governs
`[YYYY-05-31, (YYYY+1)-05-31)`, first entry governs earlier (2000-01-01 window
starts on the 1999 list); delisted included; **dropped names held to normal
exit**; candidate-only; run stages the union; `universe_schedule` spec field
default `[]` bit-identical; committed lists never rebuilt in place.

**Coverage (host store, 9,093 symbols, before the 09-14 fetch):** union
2000–2025 = 10,008; 2,862 absent, 379 `_old` twins → 2,483 real. Per vintage
2000 99%, 2009 96%, 2019 98% (09-08 fetch), 1999 79%, 2003–2015 84–88%.
Fetch launched 09-14 ~11:10 PT (`/tmp/pit-fetch/fetch.sh`, 09-08 recipe);
the vintage-date check (first bar ≤ vintage + 90 d) must run before any
rebuild — TMS lesson.

**Sequence:** 1 docs (#2808) → 2 fetch (host) → 3a `universe_schedule`
mechanism (feat-backtest, ~250 LOC) → 3b warehouse `_v11pit` (union ∪ GSPC.INDX
∪ old-manifest extras, twin dedupe, SGP_old1 + #2782) → 4 a0 null × 3 salts →
new band + goldens re-pin → 5 grid-rule update → 6 top-of-funnel screen.
Pre-migration 26y verdicts stay valid as paired reads on the year-2000 list.

Related: [[project_warehouse_vintage_coverage]], [[project_pit_survivorship_inflation]],
[[project_composition_golden_survivor_bias]], [[project_tier4_goldens_pit_migration]],
[[project_record_rebase_2026_09_09]].

**2026-09-14 ~12:00 PT — steps 1 and 2 DONE.** #2808 (plan) and #2809 (fetch record) merged.
Fetch: 2,798 OK / 109 MISS in 6 min (the "1–2 days quota" estimate was wrong ~300×);
3 ticker reuses quarantined by the vintage-date check (APXT, EXCE, TMS — TMS had been
quarantined to /tmp on 09-08 and was re-fetched; quarantine list now in-repo at
`dev/experiments/pit-universe-2026-09-14/results/quarantine.txt`, and any fetch must skip
it). 88% of fetched names are dead at real dates. Store 9,093 → 11,888. Coverage after:
every vintage 2000–2025 ≥ 95.7% (floor 2008), 1999 96.2%; union 99.1% of real names /
**95.3% counting the 379 absent `_old` twins** — the D6 manifest check must expect ~471
absent, not 92. Superset spec for 3b staged at `/tmp/pit-fetch/specs/superset-pit.sexp`
(10,504 = union 1999–2025 ∪ GSPC.INDX ∪ SPDR ETFs/global indices, minus MEL + quarantined).
SGP_old1: 424 rows after 2009-11-03 (series to 2011-11-15, ~$7); no tail-cut exception
form exists → one-off store edit in 3b. Step 3a dispatched to feat-backtest 11:15 PT.
**12:40 PT** — SGP_old1 tail cut DONE in the host store (`data/S/1/SGP_old1/data.csv`, rows after
2009-11-03 removed, 3,405 → 2,981; original at `/tmp/pit-fetch/quarantine/SGP_old1.orig.csv`; log in
`/tmp/pit-fetch/store_edits.txt` — commit that record with 3b). Existing `_v10dedup` warehouses are
untouched; only future builds see the cut. #2816 (step 3a) went CI green → structural APPROVED (posted as
an issue comment, converted) → Codex advisory NEEDS_REWORK (4 findings) → behavioral NEEDS_REWORK
(verified Codex 1/2/3b/4 + two of its own: fold propagation untested, `leak_repro.ml` unguarded);
rework iteration 1 dispatched 12:35 PT.
**18:47 PT — step 3a MERGED (#2816, 3a20f4987):** `Scenario.universe_schedule : (Date.t * string) list [@sexp.default []]`;
`Scenario_lib.Universe_schedule` (`load` rejects `Full_sector_map` and empty `Pinned []`; `members_at`, `union_sector_map`,
`is_member`, `sector_map_of_unscheduled ~runner_name` — the single guarded resolver every non-scenario runner now uses);
`run_backtest ?universe_membership_at` → `Panel_strategy_builder` (rejects a schedule for `Sector_rotation_weinstein
{use_scenario_universe=true}`) → `Weinstein_strategy_macro._membership_at_callback_of` = `pi && scheduled`. One rework
iteration (behavioral: 6 items incl. Codex's sector-rotation gap). Residual (non-blocking): the `(pi=true,sched=true)`
truth-table row is unpinned — add when step 4's spec lands. Step-3b worktree pinned at `.claude/worktrees/sweep-pit`
(3a20f4987); exes building; `rebuild-pit.sh` + `superset-pit.sexp` + `a0-pit-null.sexp` staged under `/tmp/pit-fetch/`.
**19:31 PT — step 3b LAUNCHED:** `/tmp/pit-fetch/rebuild-pit.sh` → `/tmp/snap_top3000_pit_v11pit` in the container,
run tree `.claude/worktrees/sweep-pit` @ 3a20f4987 (#2816 merged), superset 10,504 names, `-dedupe-rename-twins
-twin-basis returns -tail-exceptions warehouse_exceptions.sexp`, start 1998-01-01. Log `/tmp/pit-fetch/rebuild-pit.log`;
artifacts copy to `dev/experiments/pit-universe-2026-09-14/results/*_pit_v11.*`. Host disk was 24 GB before
`tmutil thinlocalsnapshots / 40000000000 3` → 69 GB (23 → 7 snapshots). Container-exclusive: no agents until DONE.
Step 4 spec drafted at `/tmp/pit-fetch/specs/a0-pit-null.sexp` (27-entry schedule 1999–2025); chain script to write.
**19:36 PT — single-pass 10,504-name build_snapshots OOM-killed** (exit 137 after ~5 min in the load phase, 7.2 GB,
0 snaps; log kept as `results/build_pit_v11_singlepass_oom.log`). The builder loads every CSV before writing; ~3,000
names fit, ~10,500 do not on 7.75 GB. Plan B launched 19:37: `rebuild-pit-chunked.sh` — four first-letter chunks
(A..CXIPY / CXM..JPM-PL / JPM-PM..RDEN / RDFN..ZZ, 2,626 each, no `_old` twin pair straddles a boundary) built
sequentially with `-incremental` into one dir. Caveat: the rename-twin pass sees one chunk at a time, so a renamed
pair split across chunks is not deduped — V6 on the step-4 null is the check; report cross-chunk twin groups from the
four `rename_twin_report_pit_v11_chunk*.txt`.
**21:46–21:55 PT — 3b DONE, step 4 RUNNING.** Chunked build: 4 chunks exit 0, 9,513 snaps (28–41 min each). D6 check
then ABORTED lane A: 523 real union names absent — the rename-twin pass dropped 446 legs (316 groups) because the
union carries both tickers of every rename (the vintage lists ALREADY list both legs, e.g. 2005 has ABFS and ARCB: the
store backfills the new ticker's history), and 86 of those legs are FALSE transitive drops (match < 0.95, some with
overlap 0 — issue filed). Fix without code: (1) alias map from the 360 legit legs (match ≥ 0.95), applied to the 27
lists with per-list dedupe → aliased series staged UNTRACKED in the pinned worktree at
`trading/test_data/backtest_scenarios/pit-v11/composition/` (entries 81,000 → 78,613; effective PIT breadth ≈ 2,900
unique instruments per year, not 3,000); (2) chunk 5 = the 84 false legs rebuilt as their own series, no dedupe,
`-incremental` → manifest 9,597. D6 clean: absent real = 101 = 97 MISS + 3 quarantined + MEL. Spec
`/tmp/pit-fetch/specs/a0-pit-null.sexp` now points at `pit-v11/composition/…`. Lane A (s0 then s2) launched 21:54 PT;
lane B (s1) STOPPED at 21:56 — two workers hit 6.5 GB on the 9.6k-name warehouse; run s1 after lane A. Single worker
sits at ~5.5 GB (the union-wide `_classify_all` screen — the plan's optional pre-prune is now worth doing).
