# Canonical record baseline — 2026-08-24 (book-faithful stops basis)

**THE pinned record-convention baseline** per the #2503 resolution (user ack
2026-08-24) and the #2486 §2.1 stops-basis decision. Supersedes the
unreproducible grid1-null 305% record (ladder-3-era build, params never
committed) AND the 08-23 instr-null 243% interim basis (pre-flip defaults).

- Build: `c7660cac3` (main, includes PR #2530's flips: `initial_stop_buffer
  1.0`, `reset_anchor_on_stalled_cycle true` — inherited as defaults, not
  pinned in the spec). **params.sexp committed** — the provenance rule #2503
  taught.
- Spec: `specs/record-baseline.sexp` (grid1-null config lineage; rest_weeks 0
  pin retained; both flip knobs deliberately unpinned so the baseline tracks
  the shipped defaults).
- Warehouse `/tmp/snap_top3000_dedup_v5thin_adj` (mtimes 2026-07-28),
  universe top-3000-2000, 2000-01-01..2026-06-26, `--parallel 1`.

## Headline (vs the two prior bases)

| metric | grid1-null (retired) | instr-null 08-23 | **record-baseline** |
|---|---:|---:|---:|
| total_return_pct | 305.25 | 243.06 | **731.64** |
| total_trades | 1270 | 1182 | **780** |
| sharpe | — | 0.426 | **0.666** |
| max_drawdown_pct | 39.10 | 24.48 | 26.63 |
| avg_holding_days | — | 34.9 | **57.6** |
| calmar | — | 0.195 | 0.313 |

⚠ Read per `mechanism-validation-rigor`: the top-line delta vs instr-null is a
single-pair comparison and the 26y noise floor (132.5pp, old basis) plus the
monster lottery apply — do NOT quote +488pp as the flips' causal effect. The
distribution-level shifts are the meaningful ones and all match the
book-faithful mechanics' predicted direction: **~1/3 fewer trades** (fewer
2%-stop whipsaw deaths), **holding time ~1.9×** (ratchet unfreeze + wider
initial stop let positions live), Sharpe +0.24 at slightly higher MaxDD.
The flips were justified on faithfulness (ledger
`2026-08-24-stops-basis-book-faithful.sexp`), not on this number.

## Convention for future arms

Every arm after 2026-08-24 diffs against THIS run. Specs that need the OLD
basis for continuity must pin `((initial_stop_buffer 1.02))` +
`((stops_config ((reset_anchor_on_stalled_cycle false))))` explicitly.

## Also in this change

The five `goldens-sp500/` postsubmit golden expected values re-pinned to the
new basis (they run soak-mode postsubmit; the armed-stoplimit one was already
red on main at the pre-flip basis — see PR #2530's post-review note).
