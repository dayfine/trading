# rename-twin-dedup

## Status

IN_PROGRESS

## Last updated: 2026-07-13

## Interface stable

NO

(`Twin_detector.Config` field set may still change when the
dispatcher-side warehouse rebuild exercises it on real data.)

## Owner

feat-backtest

## Summary

Rename-twins — the same company listed under old + new ticker with a
near-identical price series — live in the historical PIT universe
snapshots consumed by the snapshot-warehouse builder. A backtest that
holds both legs double-counts the position (the record deep run had
~$2.14M of $18.0M realized PnL, 11.9%, in clone legs). This track adds a
**default-off** rename-twin dedup pass at warehouse build time so the
duplicated legs can be dropped before the warehouse is written.

## What was built (this PR)

- `trading/trading/backtest/snapshot_warehouse/twin_detector.{ml,mli}` —
  pure, core-only detector. `Config.t` routes all thresholds
  (`min_overlap_days`, `match_fraction`, `close_epsilon`,
  `prefilter_rel_tol`) through config; `enabled` defaults `false`.
  `detect` prefilters candidate pairs by shared anchor-date price
  proximity (anchors every `min_overlap_days/2`-th distinct date; sorted
  near-equal runs), verifies each with the full overlap /
  match-fraction criterion (≥100 shared days, >95% closes identical
  within 1e-4 relative), unions verified edges into components (triples
  handled), and keeps the latest-`data_end` leg (ties → lexicographically
  smallest). `survivors` / `render` expose the result + a human-readable
  sidecar report.
- `build_scenario_snapshots.ml` — wired the pass in behind a
  `-dedupe-rename-twins` CLI flag (default off) + optional threshold
  flags; when armed it loads windowed bars, detects, writes
  `<output-dir>/rename_twin_report.txt`, and passes the surviving symbol
  set to `Build_runner.build`. Default-off → symbol set unchanged, no
  report (existing warehouses / goldens stay reproducible).
- Tests: true twin pair (one survives), brief-coincidence pair (both
  kept — guards the V6 BALL/TAP false positive), triple group, `_old`
  suffix leg dropped, below-min-overlap not-twin, disabled passthrough,
  reported match-fraction.

Verify: `dune build && dune runtest trading/trading/backtest/snapshot_warehouse/test/`

## What was built (v2 — returns-basis comparison)

Real-data finding: the v1 level-basis detector, armed on the real
top-3000 warehouse, found 15 exact-feed rename groups (incl. NLS/BFX)
but **missed 9 of the 10 known rename-twin groups** — the two feeds
carry different adjustment bases, so the adjusted-close *levels* diverge
(constant or drifting ratio) even though it's the same instrument.
Measured on the CSV store: level match@1e-4 was 0.000–0.831 for those 9
pairs (all below the 0.95 bar), while their **daily-return** match
(|ret_a − ret_b| ≤ 1e-3 absolute) was 0.951–0.993 (all above). Controls
BALL/TAP and ASB/CDX_old (different companies) score 0.055 / 0.061 on
returns → correctly rejected.

v2 adds a `basis` axis to `Twin_detector.Config`:

- `type basis = Levels | Returns [@@deriving sexp, equal]`;
  `basis : basis [@sexp.default Levels]` + `ret_epsilon : float
  [@sexp.default 1e-3]`. `Levels` = exactly the v1 behaviour
  (bit-identical; existing 9 tests untouched, un-annotated config sexps
  parse unchanged). `Returns` = twin iff ≥ `min_overlap_days` shared
  dates AND > `match_fraction` of consecutive-shared-date return pairs
  have `|ret_a − ret_b| ≤ ret_epsilon` (absolute). Return pairs whose
  prior close ≤ 0 are skipped (undefined return); fraction is over the
  valid pairs.
- **Prefilter is basis-aware** so it stays scale-invariant under
  `Returns`: anchors on the anchor-date *return* (each leg's close vs
  its own prior bar) instead of the close, grouping near-equal *returns*
  (absolute gap) rather than near-equal levels (relative gap). Preserves
  the documented completeness property — a dense ≥ `min_overlap_days`
  overlap always contains an interior anchor where both legs have a
  defined, near-identical return (a leg's first bar has no prior return
  and is harmlessly skipped). Documented in the `.mli`.
- CLI: `build_scenario_snapshots` gains `-twin-basis <levels|returns>`
  (default levels) + `-twin-ret-epsilon` (default 1e-3). Report header
  now prints `basis=` + `ret_epsilon=`; per-group `match=` fraction is
  the return-match fraction when basis=returns.
- Tests (extend `test_twin_detector.ml`, 16 total): scaled twin
  (×0.78 — levels miss, returns catch), drifting-ratio twin (mid-series
  2:1 step — returns catch at 38/39=0.974, levels miss), independent
  same-start-price control (not a twin under returns), scaled/drifting
  pairs explicitly missed under levels, tie-break + offset-window
  re-hold under returns.

Verify: `dune build && dune runtest trading/trading/backtest/snapshot_warehouse/test/`

## Rebuild + re-run executed (2026-07-13, dispatcher)

Deep warehouse rebuilt with `-dedupe-rename-twins -twin-basis returns`:
**83 groups / 91 legs dropped** (2999 → 2908). All 10 known groups caught;
ASB/CDX_old and BALL/TAP correctly NOT flagged (proven non-twins by
return-match 0.06); survivors verified to carry full back-history. 28y
honest-tradeable re-run on the deduped basis: MTM +3407.4%, realized
$10.37M (+1037%, still > SPY TR +700%), 1171 trades, Sharpe 0.68,
MaxDD 40.9%. Full writeup + why the haircut exceeds the 12% estimate:
`dev/notes/dedup-record-rerun-2026-07-13.md`. Validator over the run:
audit join 1171/1171, V5 PASS, V6 down to its 2 known false positives.

## Next task

None on this track — deduped warehouse is the record basis. Optional:
V6's trade-level heuristic could consult the builder report to drop its
2 standing false positives.

## Follow-ups

- v1 drops the whole losing leg, not just the overlapping window. For
  true rename-twins (duplicated series) this is correct; if a partial
  overlap ever needs the dropped leg's independent tail, revisit.
- The prefilter assumes reasonably dense daily overlap; extremely sparse
  overlaps could be missed.
