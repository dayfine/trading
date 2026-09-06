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
