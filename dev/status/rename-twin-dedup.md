# rename-twin-dedup

## Status

IN_PROGRESS

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

## Next task (dispatcher-owned)

Rebuild the deep warehouse with `-dedupe-rename-twins`, diff the emitted
`rename_twin_report.txt` against the 10 known twin groups (NLS/BFX,
ISIS/IONS, JW-A/JWA/WLY, COR/ABC(+COR_old), BKR/BHI, BLL/BALL, SWM/MATV,
TXNM/PNM, NVRI/HSC, SJW/HTO; plus new candidate ASB/CDX_old), then re-pin
the record deep-run goldens on the deduped warehouse and re-measure the
realized-PnL delta. This is a warehouse rebuild + golden re-pin — kept
out of this code-only PR.

## Follow-ups

- v1 drops the whole losing leg, not just the overlapping window. For
  true rename-twins (duplicated series) this is correct; if a partial
  overlap ever needs the dropped leg's independent tail, revisit.
- The prefilter assumes reasonably dense daily overlap; extremely sparse
  overlaps could be missed.
