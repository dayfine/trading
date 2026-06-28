# Representative trade sample (2026-06-27)

A **representative** (not cherry-picked) sample of 8 trades, taken at evenly-spaced
intervals through the date-sorted trade log of the broad top-3000 long-only deep
run — so it mirrors *typical* trades, unlike the curated extremes in
`../give-back-2026-06-27/`. The strategy's real mix is **34.6% winners / 65.4%
losers**; this sample is ~3 small wins / 5 small losses across 1998-2023.

Legend (same as the other chart dirs):
- 🔵 S1 base · 🟢 S2 advance · 🟠 S3 top · 🔴 S4 decline · ⚫ 30w MA
- 🟢 green line+dot = our entry · ⚫ grey line + 🔴 red dot = our exit
- 🟣 magenta = initial stop · 🔴 red = reconstructed structural trailing stop
  (Weinstein correction-based ratchet, default config; the *hard floor*)

| chart | trade | outcome |
|---|---|---|
| `ABDR_old.png` | 1998-08 (7d) | +2.2% stop |
| `LCTX.png` | 2004-02 → 05 | −10.5% stop |
| `ETD.png` | 2007-01 → 03 | −4.9% laggard |
| `FSS.png` | 2010-12 (3d) | +2.2% stop |
| `COLB.png` | 2014-09 (5d) | −3.6% stop |
| `QGEN.png` | 2018-02 (7d) | −6.2% stop |
| `ORCL.png` | 2020-06 → 07 | +5.7% laggard |
| `TDS.png` | 2023-08 → 09 | −0.1% stop |

**What the typical trade looks like:** small-cap or middling entries that *don't
follow through* — many are one-week spikes or bounces bought on a Stage-2 tag, then
stopped within days for a small loss. This is the 65%-loser reality: the edge is not
per-trade accuracy (it isn't there), it's the rare fat-tail winner held long enough
to pay for the many small losses (`project_edge_is_the_fat_tail`,
`project_accuracy_is_unreachable_diversify_instead`). Contrast with
`../give-back-2026-06-27/` (the few big winners) to see both tails.
