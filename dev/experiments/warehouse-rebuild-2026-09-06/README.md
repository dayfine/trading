# Warehouse rebuild on the data-layer fix, V16/V17 acceptance, salted record re-base (queued 2026-09-06)

**Status: QUEUED** — runs in this order once PR #2692 merges (it carries the `delisted`
exit and the V16/V17 validator the acceptance step reads). Each step is
container-exclusive: no agents alongside a rebuild or a 26y cell
(`container-capacity-scheduling.md`).

## Queue

| # | task | script / PR | done when |
|---|---|---|---|
| 0 | Merge #2692 (PR-C) after its gates | — | main green |
| 1 | Pin a worktree at merged main; build `build_snapshots.exe`, `scenario_runner.exe`, `post_run_validator_cli.exe` | `git worktree add --detach .claude/worktrees/sweep-wh0906 <sha>` + docker `dune build` of the three targets | exes present |
| 2 | Superset universes for 2000 / 2009 / 2019 = **composition ∪ the old warehouse's manifest symbols** ∪ GSPC.INDX (corrected after review: the old 2000 warehouse holds 2,908 names = 2,893 of the composition's 3,000 + 15 non-composition names (GSPC.INDX, the SPDR sector ETFs, GDAXI/N225/ISF.LSE), so its union adds those 15; the old 2009 and 2019 warehouses hold 2,033 and 2,209 names — 968 and 792 composition names were absent (the survivor tilt of `project_warehouse_vintage_coverage`), and the rebuild logs show the same names as `no CSV`: the tilt is in the CSV store, so the union cannot widen them until the gap fetch) | `make_superset.sh` output unioned with `grep "(symbol " <old-wh>/manifest.sexp`; staged in `/tmp/wh-rebuild/specs/` (done 2026-09-06 16:50 PT) | 3 files: 2000 = 3,015, 2009 = 3,001, 2019 = 3,001 symbols incl. GSPC.INDX |
| 3 | Rebuild the three vintage warehouses with #2691's build (`_v6tail` suffix; the old dirs stay for comparison) | `rebuild.sh` (~12 / ~22 / ~12 min) | manifest count = snap count; `active_through` count ≈ 1,964 on 2000; `terminal_runs.csv` per vintage copied to `results/` |
| 4 | Review `terminal_runs_2000.csv`: 13 `stub_tail` truncated, 10 `prefix_misscale` kept, 23 `long_low_tail` kept, 1 `high_price_tail` kept, 14 stray bars dropped; whitelist any genuine collapse in `trading/test_data/warehouse_exceptions.sexp` and rebuild that vintage if the list changes | by hand | list matches `delisting-guards-rerun-2026-09-06/scan/` |
| 4b | **PR-D — MERGED as #2695** (squash b0b411df6, 01:18 PT Sep 7; closes #2693; follow-up #2696 = fill-time residual): unconditional admission exclusion at `active_through` + #2693 survivor-marker fix + the stale `panel_runner` comment | feat PR, full gates | merged; then rebuild the three warehouses again (#2693) |
| 5 | **V16/V17 acceptance run**: record spec at salt 0 on the rebuilt 2000 warehouse + post-run validator | `acceptance-and-rebase.sh` (first cell) | **0 V16 fallback exits, 0 V17 stale entries**; the 7 former `stale_force_exit` rows render `delisted` (WLL1, RBAK, PCYC, CY, CHS, AZPN); CY has ONE entry; STMP exits `delisted` at ≈ $329.61, not `stop_loss` at $0.04 |
| 6 | Salted record re-base: rec26y salts 1–2 on 2000; rec5y-2000 (2000) and rec5y-2019 (2019) at salt 0 | `acceptance-and-rebase.sh` (remaining cells; ~2.7 h per 26y cell) | per-arm artifacts in `results/`; the new record is a **3-salt band**, never one number; dissect vs the old record by `position_id` |
| 7 | Golden check: the committed goldens read CSV fixtures (no warehouse built in CI), so #2691's truncation cannot move them by construction — confirm on the postsubmit golden workflows of the #2692 merge and state it | — | golden workflows green |
| 8 | Docs: record re-base entry, `project_record_rebase_*` memory, standing results restated as bands, this README's results table | docs PR (mixed → full gates) | merged |
| 9 | **MERGED as #2705** (squash 5a6ff8137, 19:17 PT Sep 7): runtime guard 3 (`stub_print_max_ratio`) retired — superseded by build-time `Series_tail`; four bar-source files byte-identical to pre-#2686; guards 1+2 stay | removal PR, full gates | merged, goldens bit-identical |
| 10 | **MERGED as #2708** (squash da4391d6f, 00:41 PT Sep 8; rework iteration 1: single strict exceptions record, `deep_bars` cut, report-only guards pinned) — PR-B: splice / ticker-reuse class at build (10 mis-scaled prefixes, 23 long low tails; the `splices.csv` findings) | feat PR | rebuild again → re-base again (salted) |
| 11 | **MERGED as #2709** (squash 077b48973, 00:46 PT Sep 8; closes #2696; rework iteration 1: fourth `CancelEntry` reason token `delisted` propagated to the closed-list docstrings + pin, shared constant with the exit side, `on_transitions` + bar-less-day tests): fill-time cancel of resting entry tickets past `active_through` — V17 = 0 by construction | feat PR, full gates | merged, goldens bit-identical |

## Not re-run

The stop-width and breadth-direction surfaces (within-cell A/B on the same defective
data; relative reads stand; levels restated on the next touch). The old-warehouse salts
run of the runtime guards (`delisting-guards-rerun-2026-09-06/chain-salts.sh`) is
CANCELLED — superseded: guard 3 retires, and the rebuild answers the same question with
the true universe. Its one completed cell (`dg-26y-off-s1` = 180.23% / 726 / maxDD 38.56,
vs 302.65% at salt 0) is kept as the salt-spread datum for the record's own level.

## Reads to pre-register

- The 26y level on the rebuilt warehouse is expected to differ from 302.65% by the same
  path-lottery mechanism as the guards-on run (the universe changes on most screens);
  the acceptance criterion is the V16/V17 zero count and the named exits, NOT the level.
- STMP: −$594k phantom becomes a small `delisted` exit; CLE stays wrong (class ii, PR-B).
- The 5y-2019 cell on the rebuilt 2019 warehouse now runs on ~2,200 names, not the ~980
  survivors of the 2000-vintage warehouse (`project_warehouse_vintage_coverage`).

## Run log

- **2000 rebuild (17:16–18:02 PT, 46 min, union superset 3,015 names):** 2,999 snaps =
  2,999 manifest entries. `terminal_runs_2000.csv`: **17 `stub_tail` truncated** = the
  scan's 13 + 4 the fresher CSV store exposes (APPB 2023 collapse to $0.0002, ESINQ
  2026, GES — Guess's 2026 cash deal at $16.81 → $0.011, MYL — Mylan→Viatris 2020-11-16,
  a new union name); 13 `prefix_misscale` kept, 28 `long_low_tail` kept, 1
  `high_price_tail` kept, 13 stray bars dropped. Every scan truncation recurs. **Step 4
  passes; no exceptions needed.**
- **Defect found (#2693):** `active_through` is stamped on **2,999 / 2,999** symbols —
  `_derive_active_through` compares the last bar to the CLI `-end-date` (2026-09-06),
  which is after the store's last bar (2026-08-17), so 778 survivors carry
  `active_through 2026-08-17` (plus clusters at 06-26 and 07-01). Harmless inside the
  record window (every survivor marker is on or after 2026-06-26 — 90 sit exactly on it —
  and the `delisted` exit fires only when `current_date > active_through`, so neither it
  nor the prune can act inside the window), wrong for any window reaching the store's end.
  Fix = derive against the universe's max last-bar with a tolerance; rebuild after.
  The acceptance run proceeds on this warehouse with that caveat pre-registered.
- **2009 rebuild (18:02–18:30 PT, 28 min, union superset 3,001):** 2,033 snaps = 2,033
  manifest entries = **exactly the old warehouse's count**; the builder logged the missing
  composition names as `skip <SYM>: no CSV`. So the survivor tilt of the 2009/2019
  vintages is in the **CSV store**, not in the old builds — the union superset cannot
  widen them until the missing delisted names are fetched (the P1 "vintage warehouse gap
  fetch" item, ~700–1,000 names per vintage via EODHD, then a Pinned rebuild). Same
  `active_through` defect as 2000 (#2693: 2,033/2,033 marked).
- **2019 rebuild (18:30–18:44 PT, 14 min):** 2,209 snaps = the old count (792 composition
  names `no CSV`); `active_through` 2,209/2,209 (#2693). **REBUILD DONE 18:44 PT.** Per-vintage
  `terminal_runs_{2000,2009,2019}.csv` in `results/`.
- **Step 7 (golden check) passes early:** main is fully green on the #2692 merge
  (552439c91) — `CI`, `perf-tier1`, `golden-runs-sp500-5y`, `golden-runs-custom-universe`
  all success; the goldens read CSV fixtures, so the build-time truncation cannot move them.
- **Acceptance cell `rec26y-new-s0`** started 18:18 PT on `snap_top3000_2000_v6tail`
  (worktree `sweep-wh0906b` @ 552439c91); result ~21:00 PT.

## Acceptance cell result (22:02 PT) — V16 PASS, V17 FAIL (3), chain stopped for PR-D

`rec26y-new-s0` on `snap_top3000_2000_v6tail` (worktree @ 552439c91, 13,441 s wall — 40% slower than `dg-26y-off-s0`'s 9,615 s on the old warehouse (`../delisting-guards-rerun-2026-09-06/README.md`, same spec, same build lineage), with a confound: the 2019 rebuild overlapped this cell's first 26 minutes (18:18–18:44), against the queue's own container-exclusive rule, so part of the gap is contention): **165.16% / 715 / Sharpe 0.31 / maxDD 42.37**
— a level, and per the pre-registration NOT the criterion (path lottery: the universe
differs from the old warehouse on most screens). The criteria:

| criterion | result |
|---|---|
| 0 V16 fallback exits | **PASS** — `exit_trigger` counts: `delisted 10, laggard_rotation 234, stop_loss 464, extension_stop 3, stage3_force_exit 2, liquidity_exit 2`; zero `stale_force_exit`, zero blank |
| the former `stale_force_exit` rows render `delisted` | **PASS** — WLL1, RBAK, CY, CHS, AZPN on this path (PCYC is not held on this path), plus STMP, ISSX, FII ×2, ANDV |
| STMP exits `delisted` near $329.61 | **PASS** — 2021-10-05 at 329.61, +$4,189 (was `stop_loss` at $0.04, −$593,988) |
| CY entered once | PASS on the count — but that one entry (2020-04-25) is itself stale |
| 0 V17 stale entries | **FAIL — 3**: FII 2020-03-28 and 2020-04-04 (last bar 2020-01-31; 57 / 64 days), CY 2020-04-25 (last bar 2020-04-15; 10 days). All three are entries on a symbol whose `active_through` had passed; the run's own `delisted` exit then closed each within two days (−$845, −$844, −$122) |

Note on the first validator pass: my chain pointed `post_run_validator_cli` at the
worktree's fixture CSVs (`test_data`, 655 symbols ending 2025-05-16), which skipped 506
entries and flagged five survivors (LLY, INFY, CP, COST, BP) against the fixture's end date.
Re-run with `-data-dir /workspaces/trading-1/data` (the real store) → the 3 rows above;
`acceptance-and-rebase.sh` fixed. Both validator outputs are in `results/`.

**Consequence.** Admission still lets a symbol in after its marker has passed: the record
convention has guard 1 (`entry_max_bar_age_days`) at its default 0 and the screener's PI
filter behind `enable_pi_filter` (default false). Per the principle, the marker is data,
not a mechanism: **PR-D** makes exclusion at admission unconditional when
`active_through < as_of` (same shape as the `delisted` exit), and carries the #2693 fix
(survivor markers). Then: rebuild the three warehouses (#2693), re-run this cell (expect
V17 = 0 and 712 trades), then the salts. The chain was stopped at 22:03 PT after this
cell; `rec26y-new-s1` had just started and is discarded.

## Second rebuild (`_v7mark`, PR #2695 tip b48537469 — the #2693 marker fix), 22:44 PT →

- **2000 (22:44–23:18, 34 min):** 2,999 snaps = 2,999 manifest entries; **`active_through`
  on 2,217** (was 2,999/2,999 on `_v6tail`): 782 survivors within the 7-day tolerance of the
  universe's last bar (778 sat exactly on 2026-08-17 before). The old scan counted 1,964
  series ended before 2026-06 on 2,908 names; 2,217 on 2,999 names with the cutoff at the
  store's last bar (2026-08-17) minus the 7-day tolerance (i.e. 2026-08-10) is consistent. Reports in `results/terminal_runs_<v>_v7.csv`.
- **2009 (23:18–23:40, 22 min):** 2,033 snaps = 2,033 manifest entries; **`active_through`
  on 817** (was 2,033/2,033) — 1,216 survivors within the tolerance.
- **2019 (23:40–23:52, 12 min):** 2,209 snaps; **`active_through` on 543** (was
  2,209/2,209) — 1,666 survivors. **Second REBUILD DONE 23:52 PT.** The three `_v7mark`
  warehouses are the inputs for the second acceptance run (`acceptance2.sh`).

## Second acceptance cell (04:12 PT Sep 7) — **V16 PASS, V17 PASS**; chain continues into the salts

`rec26y-new-s0` on `snap_top3000_2000_v7mark` (worktree `sweep-wh0906c` @ b48537469 — PR #2695's tip at launch; the four commits that
followed before the squash b0b411df6 are docstrings and one test-helper rename, so the
build is code-identical to merged main; validator against the real CSV store;
10,402 s wall): **263.16% / 707 / Sharpe 0.39 / maxDD 42.37** — a level, not the criterion.

| criterion | result |
|---|---|
| 0 V16 fallback exits | **PASS** — `delisted 7, laggard_rotation 242, stop_loss 450, extension_stop 3, stage3_force_exit 3, liquidity_exit 2`; zero `stale_force_exit`, zero blank |
| 0 V17 stale entries | **PASS** — CY and FII are never entered (their markers precede every screen after 2020-01-31 / 04-15); PR #2695's admission gate did what the first run showed was missing |
| former `stale_force_exit` rows render `delisted` | **PASS** — WLL1, RBAK, CHS, AZPN (PCYC not held on this path), plus STMP, ISSX, ANDV |
| STMP exits `delisted` near $329.61 | **PASS** — 2021-10-05 at 329.61, +$4,195 (was `stop_loss` at $0.04, −$593,988) |

Artifacts: `results/rec26y-new-s0-v7-*` (actual / trades / params / summary / open_positions /
validator `.sexp` + `.md`), `rec26y-new-s0-v7.validator.log`, `chain2.log`, `rebuild2.log`.
**The data is clean under the acceptance criteria.** The chain rolled into
`rec26y-new-s1` at 04:12; salts 1–2 (~2.9 h each on this warehouse) and the two 5y cells
follow, ETA ~13:30 PT. The new record is the 3-salt band from those cells (step 6); the
level above is one draw of it. Caveat carried: the fill-time residual (#2696) is bounded
under V17's threshold, so V17 = 0 is evidence by margin.

## Step 6 — salted re-base cells (chain done 10:43 PT Sep 7). Every cell V16 PASS / V17 PASS.

| cell | warehouse | return % | trades | Sharpe | maxDD % | wall | exit triggers (no blank, no `stale_force_exit`) |
|---|---|---:|---:|---:|---:|---:|---|
| `rec26y-new-s0` | 2000 `_v7mark` | 263.16 | 707 | 0.39 | 42.37 | 10,402 s | delisted 7 / rotation 242 / stop 450 / ext 3 / s3 3 / liq 2 |
| `rec26y-new-s1` | 2000 `_v7mark` | **561.61** | 705 | 0.52 | 45.15 | 10,160 s | delisted 3 / rotation 239 / stop 455 / ext 2 / s3 5 / liq 1 |
| `rec26y-new-s2` | 2000 `_v7mark` | 180.89 | 755 | 0.32 | 42.18 | 10,618 s | delisted 4 / rotation 251 / stop 489 / ext 3 / s3 6 / liq 2 |
| `rec5y-2000-new-s0` | 2000 `_v7mark` | 76.69 | 98 | 0.66 | 28.35 | 1,389 s | delisted 1 / rotation 19 / stop 74 / ext 3 / s3 1 |
| `rec5y-2019-new-s0` | 2019 `_v7mark` | 42.37 | 175 | 0.50 | 21.65 | 1,267 s | delisted 1 / rotation 39 / stop 135 |

Artifacts: `results/<cell>-v7-{actual.sexp,trades.csv,params.sexp,summary.sexp,open_positions.csv,validator.sexp.sexp,validator.sexp.md}` + `<cell>-v7.log`, `chain2.log`.

**Reconciliations owed from earlier sections.** (1) The first acceptance section pre-registered
"expect V17 = 0 and 712 trades" for the re-run; V17 = 0 landed and the count is **707**: the
first run's 715 minus the 3 stale entries = 712 was the naive expectation, but removing three
entries also frees cash and slots on those weeks, so the path re-picks — 707 vs 712 is that
divergence, not a defect (every row is V16/V17 clean). (2) `results/terminal_runs_*_v7.csv` are
**byte-identical** to their `_v6tail` counterparts — the #2693 fix changed only the survivor-
marker derivation, an invariance control on the truncation rule.

### The 26y band, dissected (`symbol|entry_date` join across salts)

369 trades are shared by all three salts. The **+300pp between salts 0 and 1 is two monsters
present only in salt 1's path**: AEIS 2025-06-24 → 2026-05-20 (**+$972,866**, stop_loss) and
MOS 2006-10-30 → 2008-01-23 (**+$806,294**, stop_loss); the shared 2020 winners (LOGI, BBWI,
NVDA) then fill at identical prices for ~1.75× the P&L because the salt-1 path carries more
equity into 2020. Realised P&L: s0 +$2.44M / s1 +$4.97M / s2 +$1.74M; open-position value at
the end 1.67M / 3.70M / 1.61M. This is `project_edge_is_the_fat_tail` and
`project_clock52_promoted`'s "26y = salt lottery" once more, now on clean data: the AEIS-2025
monster the 09-03 rebase named as "the gap" is a salt-1-only event.

### Record re-base (the deliverable of the queue)

The canonical record is now **the band on the clean 2000-vintage warehouse**, not one number:

| statistic | s0 | s1 | s2 | median |
|---|---:|---:|---:|---:|
| total return % | 263.16 | 561.61 | 180.89 | **263.16** |
| trades | 707 | 705 | 755 | 707 |
| Sharpe | 0.39 | 0.52 | 0.32 | 0.39 |
| maxDD % | 42.37 | 45.15 | 42.18 | 42.37 |

versus the old record on the defective warehouse: 302.65 (s0) / 180.23 (s1) — a comparable
spread; the level shift is path lottery, the drawdown is ~6pp worse across all salts (worth
its own dissection before any stop-width read is re-stated). **Quote the record as
"263% median, 181–562% across salts 0–2, maxDD 42–45%"**, never as one draw. Every
pre-09-07 "standing result" is superseded; the stop-width and breadth-direction surfaces
keep their within-cell reads and get re-stated on their next touch.

Universe note for the 5y cells: 2000 (98 trades) and 2019 (175 trades, on a 2,209-name
warehouse that still lacks 792 composition names — the gap fetch is the remaining P1).

## Paired armed-splice rebuild (2026-09-08 00:51 → 01:28 PT) — control arm read, treatment KILLED, #2711 filed

`rebuild3.sh`: `build_scenario_snapshots.exe` @ 077b48973 (pinned `sweep-wh0908`; the splice flags exist only on this scenario-driven builder, which needs `-fixtures-root`), spec `specs/wh-2000-superset.sexp` (the rec26y record window over the staged 2000 superset, 3,015 symbols, window 1999-01-02..2026-06-26), `-tail-exceptions` = the committed file. Control arm `-detect-splices -no-splice-action` built in 36 min: 2,999 snaps; detector = 11,171 findings across 591 symbols; `series_splice` classes **interleaved 67 / prefix_misscale 6 / reuse 518**, all `kept` (report-only). `results/splice_actions_2000_v8ctl.csv`.

Cut depth derived from the bar store (`results/reuse_cut_depth_2000_v8ctl.csv`, the sidecar reports `n_dropped = 0` in report-only mode — #2711 item 3): for the 518 `reuse` symbols the armed rule would drop p10 455 / **p50 2,033** / p75 3,269 / p90 4,906 / max 6,805 bars; **≥90% of the series for 247 symbols**, 50–90% for 143. The deepest cuts are terminal corporate events — GES 2026-01-22 (taken private; 6,805 of 6,848 bars), NKTR, TUPBQ/TUP, BIG, HIBB, RAD, EMMS, BFX — so "keep the later segment" keeps the stub and deletes the company. The treatment arm was killed at 01:28 and `_v8splice` deleted; nothing was re-based on it. The `_v7mark` warehouses and the §Step 6 band stand. Fix = #2711 (reuse default `Kept`; cut only by exception; refuse cuts that leave < 250 kept bars; `n_dropped`/`n_kept` in report-only). The 67 interleaved drops (CLE 412, ICT 589, KBL 569, SWD 1215, TIN 422, UCM 373, SIB 638, …) and the 6 prefix cases (BANB, BKNG 1999-03-29, HPC, HSBA, SBER, SGY) look right and stay.

Lesson: **dry-run any bar-discarding build rule on a real vintage and read its depth distribution before trusting the armed build** — the report-only arm is the cheap control, and one read caught this.
