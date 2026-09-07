---
name: project_delisting_guards_2672
description: "#2672 root causes (2026-09-05): active_through is plumbed end-to-end but NEVER populated (EODHD parser None, zero manifest entries in all 3 warehouses); stale-bar entries become zombies because get_previous_bar is capped at 60 days so stale_exit never fires; stub-print tails (STMP) pass the close>0 guard. Two defect classes: clean tail (STMP) vs interleaved-series splice (CLE/ICT/ABK/MEL/MVL/AGR, 66 symbols with >=20 flagged bars in splice-scan.csv). Fix = three default-off guards (feat/delisting-guards-2672)."
metadata:
  type: project
---

**Measured 2026-09-05** (issue #2672 comment, session-side scan of 92 committed
`*trades.csv` + `dump_snap` on the warehouses).

**Three root causes, none of them "the marker was wrong":**
1. `Daily_price.active_through` / `Snapshot_manifest.file_metadata.active_through` /
   `Daily_panels.active_through_for` / `Snapshot_callbacks.active_through_for` all
   exist, but the EODHD bar parser leaves it `None` ("needs a separate enrichment
   pass", `http_client.ml` ~l.157) and `grep -c active_through manifest.sexp` = 0 on
   `snap_top3000_dedup_v5thin_adj`, `snap_top3000_2009`, `snap_top3000_2019`. The
   PI filter (`enable_pi_filter`, default off) is also fail-open on `None`. Any
   guard keyed on the marker guards nothing.
2. **Stale entry → zombie.** `entry_audit_helpers.latest_close` takes `List.last`
   of `daily_bars_for ~as_of` with no recency check (DTV: last bar 2019-09-30,
   entered 2020-03-28 at the retained $58.09). The run armed
   `stale_exit_after_days 5`, but `Stale_hold.force_exit_candidates` needs
   `get_previous_bar <> None` and `Snapshot_bar_source._previous_bar_lookback_days = 60`
   — so a position entered on bars already >60d stale is never realised and is
   valued 0.00 at window end (in `open_positions.csv`).
3. **Stub tail.** `Market_data_adapter._is_valid_bar` rejects only `close <= 0`;
   STMP's $0.045/$0.03 post-takeover prints are real bars, so `check_stop_hit`
   fires and the Market sell fills at the stub open. −$594k in the record,
   present in 56/92 trade sets. The next-open exit gate (D1) does not help — the
   stub IS a fresh bar.

**Two defect classes** — a tail guard fixes only the first:
- Clean terminal collapse: STMP (329.61 → 0.045 to series end).
- Interleaved series / mis-scaled prefix: CLE (0.70 and 0.03 alternate for months,
  entry-day bar `open 71.91 / close 0.68`), ICT (zero-volume ~$220 prints between
  real ~$110 bars and $0.03), ABK, MVL (33 → 1.90 splice 2008-06-30, never
  recovers), AGR / MEL (raw ~70k / ~175k prefixes). The #2649 splice scan
  (`dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv`, 603 symbols)
  already names all of them: 66 symbols have >=20 flagged bars. Needs a per-bar
  plausibility gate or a warehouse-build drop — sibling issue, not #2672.

**Fix MERGED 2026-09-06 (PR #2686, squash 1b7295cae; 2 rework iterations):** three
default-off knobs: `entry_max_bar_age_days` (entry recency), stale force-exit when
no prior bar is within the lookback (under the existing `stale_exit_after_days`),
`stub_print_max_ratio` (terminal-run truncation at the shared bar layer). Paired
26y record re-run + record re-base owed after merge (STMP −$594k, CLE −$147k, DTV
move; wide-stop arms move too).

Related: [[project_saturday_stale_fill_defect]], [[project_record_rebase_2026_09_03]],
[[project_exit_fill_reject_zombie]], [[project_warehouse_vintage_coverage]].

**Paired re-run (2026-09-06, build 3113f751e, salt 0,
`dev/experiments/delisting-guards-rerun-2026-09-06/`).** 5y-2019: off 16.79% / 179
reproduces the null; on 52.12% / 169 — the whole +35pp is STMP. 26y: off reproduces the
record digit-for-digit (302.65 / 723 / 36.26); **on = 139.81% / 714 / Sharpe 0.29 / maxDD
38.39 — 163pp BELOW**. Dissection: the stub-tail guard trims EVERY dying symbol's terminal run, so the
universe differs on 1,292 of 1,335 screens from 2000-01-14 (gap up to 22, on 11 screens in 2017; 2016 max 20); the
first top-20 pick that flips is 2003-06-12 (BKNG→SEIC) and the paths never reconverge (457/720 shared; off-only +$1.25M vs on-only
+$35k). **Path lottery, not a guard cost; do not re-base on it.** Lesson: ANY per-symbol
data-hygiene change (twin dedup, splice drop, tail truncation) perturbs the 26y path the
same way — a re-base after one needs salts, never a single pair. Options: salts 1–2 of
both arms, or arm guards 1+2 only (no universe effect) in the record convention.

**Data-layer fix landed (2026-09-06 evening).** #2691 (build-time
`Snapshot_pipeline.Series_tail`: `active_through` from series end, stub-tail truncation
only when ratio ≤ 0.05 AND run ≤ 60 bars AND stub close < $1, stray-bar drop,
`terminal_runs.csv` review report, `warehouse_exceptions.sexp`) and #2692 (first-class
`delisted` exit at `active_through`, `stale_force_exit` label reaches trades.csv (#2687
closed), validator V16 fallback-exit report + V17 stale-entry-bar check, default 7
days, `Forced_exit_step` ordering) are MERGED. Runtime guard 3 (`stub_print_max_ratio`)
retires under Rule 4 once every live warehouse is a `_v6tail` rebuild.
**Queue** = `dev/experiments/warehouse-rebuild-2026-09-06/README.md` (10 steps): union
superset universes (composition ∪ old warehouse) → rebuild 2000/2009/2019 (`_v6tail`) →
review report (2000: 17 truncated = scan's 13 + APPB/ESINQ/GES/MYL from the fresher
store) → V16/V17 acceptance run (0 fallbacks, 7 `delisted` rows, one CY entry, STMP
`delisted` ≈ $329.61) → salted re-base as a 3-salt band → golden check → docs → retire
guard 3 → PR-B splice class. **#2693:** the rebuild stamps `active_through` on EVERY
symbol (2,999/2,999) because the derivation compares to the CLI `-end-date`, not the
store's max last-bar; harmless inside the record window, must be fixed before any window
reaching the store's end. Old-warehouse salts run cancelled (its one cell: record at salt
1 = 180.23% vs 302.65% at salt 0 — the record's own level is a salt lottery).
**Acceptance (2026-09-06 22:02 PT, rebuilt 2000 warehouse):** V16 PASS (0 fallback exits;
10 `delisted` rows incl. STMP at $329.61 — the −$594k phantom is gone); **V17 FAIL: 3
stale entries** (FII 2020-03-28/04-04 after its series ended 01-31; CY 04-25 after 04-15)
because admission has no unconditional `active_through` exclusion (guard 1 off in the
record convention; PI filter behind `enable_pi_filter`). PR-D = make it unconditional
(data-driven) + fix #2693 (survivor markers; builds mark 2,999/2,999). Validator gotcha:
`post_run_validator_cli -data-dir` must be the REAL CSV store (`/workspaces/trading-1/data`),
not the worktree's `test_data` fixtures (655 symbols ending 2025-05-16 → 506 skipped, 5
false V17 hits on survivors). Rebuilt-warehouse 26y cell = 13,441 s (40% slower than the
"thin" old warehouse).
**PR-D merged 2026-09-07 01:18 PT (#2695, squash b0b411df6; closes #2693):**
`Delisted_entry_gate` at the `Entry_assembly` seam (unconditional, data-driven: no entry
once `active_through` has passed; marker-day still admits, mirroring the exit), and
`Build_runner` survivor markers derived against the universe's max last-bar with
`-survivor-tolerance-days 7` (2000 vintage: 2,217 of 2,999 marked, was 2,999/2,999).
Residual (#2696): a ticket admitted on the marker day can still fill a few days later
(resting orders not re-screened; the delisted exit acts on positions only) — under V17's
7-day threshold, so a clean V17 is evidence by margin, not by construction. Second
acceptance run launched 01:19 PT on `snap_top3000_2000_v7mark` (expect V16 0 / V17 0).
**ACCEPTANCE PASSED (2026-09-07 04:12 PT, `snap_top3000_2000_v7mark`, PR #2695 build):**
V16 PASS, V17 PASS; 7 `delisted` rows incl. STMP at $329.61; CY/FII never entered; zero
blank or `stale_force_exit` rows. Level 263.16% / 707 / maxDD 42.37 (one draw; the record
becomes the 3-salt band from the cells running through ~13:30 PT). Data-layer program
complete except: retire guard 3 (Rule 4), #2696 fill-time cancel, PR-B splice class,
vintage gap fetch (2009/2019 stores lack ~970/~790 composition names).
