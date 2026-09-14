# PIT top-3000 universe migration — decisions, mechanism, sequencing

**Status:** pre-registration (step 1 of the P0 in
`dev/notes/next-session-priorities-2026-09-14.md`). User decision 04:45 PT 2026-09-14.
Written 2026-09-14 in the local session; one PR per step below.

## 0. What already exists — verified 2026-09-14, corrects the handoff

The handoff's step 2 ("extend the yearly top-1000 builder to top-3000") is
**already done**, and the runner has **no** dated-membership support. Both were
checked against main `36102f1f1`.

- **The yearly lists exist:** `trading/test_data/goldens-custom-universe/composition/top-3000-{1998..2025}.sexp`
  (28 files, 3,000 entries each, `method_ Composition_from_individuals`, one
  `(date YYYY-05-31)` per file). Built by `build_composition_universes_runner`
  (`trading/analysis/data/universe/bin/`) via `Build_from_individuals`: anchor
  YYYY-05-31, rank by `avg(close × volume)` over YYYY-03-01..05-31, inventory
  filter `data_start ≤ YYYY-04-01` and `data_end ≥ YYYY-05-31`, equity-like
  only, top 3,000. Delisted-inclusive by construction (SIVB/FRC/BBBY in 2019,
  LEH/AIG in 1998, 34 "Q" tickers in 2001 — `project_pit_survivorship_inflation`).
- **The runner fixes the universe once per run.** `universe_path` is loaded
  at `Runner._load_deps` (`trading/trading/backtest/lib/runner.ml`) into a
  `(symbol → sector)` table whose keys become `Weinstein_strategy.config.universe`;
  the snapshot's `date` is read and discarded by the `Universe_snapshot` bridge.
  `dev/plans/goldens-broad-pit-migration-2026-06-05.md` listed intra-run
  rebalancing as an explicit non-goal. Walk-forward, rolling-start and barbell
  copy `universe_path` verbatim per fold.
- **The seam already exists.** `Screener.screen_with_cooldown
  ?membership_at:(string -> Date.t -> bool)`
  (`trading/analysis/weinstein/screener/lib/screener.mli`) rejects a symbol
  *before* stage classification, sector resolution or scoring; exits and stops
  iterate the portfolio and never consult it. Today its only source is the
  `enable_pi_filter` delisting predicate
  (`weinstein_strategy_macro.ml` `_membership_at_callback_of`). The mli names
  "a stock added to the index after `as_of`" as the intended use.
- **Coverage of the host CSV store** (`data/<first>/<last>/<sym>/data.csv`,
  9,093 symbols on 2026-09-14) against the lists:

  | set | symbols | with bars | note |
  |---|---:|---:|---|
  | union of top-3000-2000..2025 | 10,008 | 7,146 | 2,862 absent; 379 of those are `_old` synthetic rename twins → **2,483 real names to fetch** |
  | top-3000-1999 | 3,000 | 2,371 | governs Jan–May 2000 under D2 |
  | top-3000-2000 | 3,000 | 2,984 | 09-08 gap fetch targeted this vintage |
  | top-3000-2003 / 2006 | 3,000 | 2,531 / 2,547 | middle vintages never fetched |
  | top-3000-2009 | 3,000 | 2,885 | 09-08 gap fetch |
  | top-3000-2012 / 2015 | 3,000 | 2,645 / 2,605 | |
  | top-3000-2018 / 2019 | 3,000 | 2,773 / 2,935 | 09-08 gap fetch (2019) |
  | top-3000-2021 / 2024 / 2025 | 3,000 | 2,640 / 2,824 / 2,954 | |

  The union with 1998–1999 is 10,923; only 1999 is needed (D2).

## 1. Decisions (recorded before building)

- **D1 — membership rule.** Top 3,000 by trailing Mar-1..May-31 average dollar
  volume, anchored **May-31** each year (Russell reconstitution cadence), i.e.
  the existing builder and the existing files, unchanged. This replaces the
  handoff's "prior-year dollar volume fixed at year start": one convention,
  already materialised, and the ranking window ends at the anchor, so there is
  no look-ahead.
- **D2 — effective window.** The list dated `YYYY-05-31` governs every
  screening date `d` with `YYYY-05-31 ≤ d < (YYYY+1)-05-31`. Dates before the
  first schedule entry use the first entry. For a 2000-01-01 start the schedule
  therefore begins with `top-3000-1999` (known by 1999-05-31), not the 2000 list.
- **D3 — delisted names included.** By construction (`data_end ≥ anchor`); they
  die at their real dates through `active_through` (#2672 guard family).
- **D4 — a held position in a name that drops out of the list is held to its
  normal exit.** No forced sell (that would invent a mechanism). Enforced by
  the seam itself: `membership_at` is consulted only by the screener cascade.
- **D5 — candidate membership only.** The macro gate and sector RS read the
  indices and SPDR ETFs from `_all_runner_symbols`, independent of the universe
  file; a schedule cannot degrade them.
- **D6 — bars for the union.** A scheduled run stages the union of all its
  lists (the run's `sector_map_override` = union) so a name keeps pricing after
  it drops out. The `_v11pit` warehouse must therefore cover the union; absent
  symbols are skipped silently by the bar reader, so the warehouse manifest is
  checked against the union before every cell.
- **D7 — default-off, bit-identical.** `universe_schedule` is a scenario-spec
  field defaulting to `[]`; an empty schedule is today's `universe_path` path.
  It is data plumbing, not a strategy mechanism, so no ledger ACCEPT gates its
  use in specs — but the **record** moves only through step 4's re-baseline PR,
  and every pre-migration 26y verdict stays valid as a paired read on the
  year-2000 vintage list (ledger note in step 4).
- **D8 — snapshot convention.** May-31 everywhere. The committed lists are
  **not** rebuilt in this migration: the composition goldens pin them, and a
  rebuild from the post-fetch store would move membership. If a rebuild is ever
  wanted it lands as a new series (never overwrite) — parked, see §5.

## 2. Mechanism (step 3a — `feat-backtest`, one PR, ~250 LOC + tests)

Thread a schedule, resolve it to a `membership_at` composition. From the
2026-09-14 seam survey:

1. `Scenario.t.universe_schedule : (Date.t * string) list [@sexp.default []]`
   next to `universe_path` (`trading/trading/backtest/scenarios/scenario.mli`).
   Paths are fixtures-root-relative like `universe_path`. The spec is the home,
   not the strategy config: the strategy lib has no fixtures notion.
2. New `Scenario_lib.Universe_schedule` (beside `universe_file.ml`):
   `load : fixtures_root:string -> (Date.t * string) list -> t`,
   `members_at : t -> Date.t -> String.Set.t` (latest entry with `date ≤ d`;
   the first entry governs everything before it — D2),
   `union_sector_map : t -> (string, string) Hashtbl.t`. Reuses
   `Universe_file.load` per path so the composition files decode unchanged.
3. `scenario_runner.ml` (`_sector_map_of_universe_file` call site): when the
   schedule is non-empty, `sector_map_override` = the union, and the
   `members_at` closure goes into `run_backtest` as
   `?universe_membership_at:(string -> Date.t -> bool)`.
4. `Runner.run_backtest` → `Panel_runner` → `Panel_strategy_builder`: carry the
   optional callback to strategy construction.
5. `Weinstein_strategy_macro._membership_at_callback_of`: compose
   `pi_ok sym d && schedule_ok sym d`, `schedule_ok` defaulting to `const true`.
   This is the whole behavioural change.
6. `Scenario_snapshot_plan.derive` / `build_scenario_snapshots.ml`: derive the
   required symbol set from the union, so a warehouse built from a scheduled
   spec covers every year.
7. The other resolvers (`walk_forward_executor`, `rolling_start_runner`,
   `barbell_scenario`, `grid_search_evaluator`, `bayesian_runner_evaluator`,
   `backtest_runner`) **fail loudly** on a non-empty schedule in this PR
   (`Scenario` validation), never ignore it; walk-forward support is a
   follow-up once the record band exists.

Tests to pin: the step function (before first entry / between / after last);
empty schedule ≡ `universe_path` bit-identical on a smoke scenario; a two-list
synthetic scenario where a name enters the list in year 2 and is screened only
from then; a held position surviving its name's drop-out (D4); the loud failure
in a walk-forward spec. Optional perf follow-up: pre-prune `_classify_all`'s
iteration by the schedule so the ~10k-name union is not stage-classified every
Friday.

## 3. Sequencing and cost

| step | what | owner | cost | depends on |
|---|---|---|---|---|
| 1 | this doc + the fence in `dev/status/backtest-infra.md` | local session | docs PR | — |
| 2 | **fetch the 2,483 union names** with the 09-08 recipe (`dev/experiments/warehouse-rebuild-2026-09-06/fetch_gap.sh`: >200-row floor, `_old` skipped) **plus the vintage-date check** (first bar ≤ list date + ~90 d; TMS lesson, `project_warehouse_vintage_coverage`) run before any rebuild; per-vintage coverage table after | local host (EODHD key is host-only) | quota-bound, ~1–2 days wall | 1 |
| 3a | the mechanism in §2 | `feat-backtest` | one PR, three gates | 1 (parallel with 2) |
| 3b | warehouse `_v11pit`: superset = union(1999..2025) ∪ `GSPC.INDX` ∪ the `_v10dedup` manifest extras (SPDR ETFs, global indices), `build_snapshots.exe -dedupe-rename-twins -twin-basis returns`, start 1998-01-01; `-tail-exceptions` carrying the **SGP_old1** decision (2009-11 merger stub prints — needs a tail-cut exception form or a store edit, decide here) and the **#2782 backfill-twin** pass if it has landed; container-exclusive | local | ~2–3 h build (3× the 46-min 2000 vintage) | 2, 3a |
| 4 | the a0 null spec with `universe_schedule` = 1999..2025, three salts on `_v11pit`, two lanes; new ledger baseline; re-pin the goldens that move (one PR, `config-default-blast-radius.md` paired statement) | local | ~9 h container | 3b |
| 5 | `promotion-confirmation.md`: with a PIT universe, universe diversity = breadth tier (top-1000 vs top-3000 schedules), period diversity = disjoint sub-windows of the same construction | local | docs PR | 4 |
| 6 | top-of-funnel screen (breakout-gate width, top-N) on the new band | — | — | 5 |

Container rule (`container-capacity-scheduling.md`): 3b and 4 run alone; QC
waves for 3a run before either.

## 4. What stays valid

Every paired 26y verdict on `top-3000-2000` (the year-2000 vintage list) is a
relative read on one fixed list and stays valid (`project_composition_golden_survivor_bias`).
Levels do not transfer: the record band (`project_record_rebase_2026_09_09`,
312 / 383 / 640 %) is a survivor-list level and is superseded by step 4's band.

## 5. Open questions (resolve in the step that owns them)

- **Why do the lists contain names the store lacks?** `Build_from_individuals`
  reads bars to rank, so the 2026-06-05 build saw bars the 2026-09-14 store
  does not have (2,483 names). Either the store was pruned since or the build
  ran against a different tree. Step 2's fetch log answers it per name
  (`OK` at a real date range vs `MISS`); if a large share MISS, the lists'
  provenance needs a note before step 3b.
- **SGP_old1 exception form** — `warehouse_exceptions.sexp` has `keep_tail`
  and `splice (cut_at …)` (prefix keep-from); a tail truncation needs either a
  new form or a one-off store edit. Step 3b.
- **`universe_size`** in specs is documentation only (`allow_extra_fields`);
  scheduled specs write `universe_size 3000` and say "PIT schedule" in the
  description.
- **1998** is not needed (D2 starts at 1999 for a 2000-01-01 window); include
  it in the schedule only if a pre-2000 window is ever run.
