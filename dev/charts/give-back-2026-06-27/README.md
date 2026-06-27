# Stage-analysis charts — give-back winners + whipsaw loser (2026-06-27)

> **Selection note:** these 6 are **curated extremes** (the 5 biggest give-back
> winners + the single biggest whipsaw loss), chosen to illustrate the give-back —
> NOT representative. The strategy is 35% win / 65% loss; for a typical-trade view
> see `../representative-2026-06-27/`, and for what actually drove the drawdown see
> `../drawdown-drivers-2026-06-27/`.

Visual diagnostics for the trades behind the broad top-3000 long-only **41.5–43.8%
MaxDD** discussion (see `dev/notes/barbell-deep-verification-2026-06-27.md` and the
session analysis). Each PNG plots **weekly close coloured by programmatic Weinstein
stage** over the **30-week MA** (black line):

- 🔵 blue = Stage 1 (base) · 🟢 green = Stage 2 (advance) · 🟠 orange = Stage 3 (top)
  · 🔴 red = Stage 4 (decline)

**Trade overlay (our actual position):**
- 🟢 **green vertical line + dot** = our entry · ⚫ **grey vertical line + 🔴 red dot** = our exit
- 🟣 **magenta horizontal line** = the **initial** stop (entry × (1 − stop-distance);
  distances here run 6%–50%, avg ~22%).
- 🔴 **red line = reconstructed structural trailing stop** (the real Weinstein
  correction-based ratchet, replayed via `Weinstein_stops`, default config, on the
  adjusted-close scale). It steps up on completed pullbacks — but it is the **hard
  floor** and it **under-trails the actual exit**.
- ⚫ **black line = 30-week MA.** Empirically, **exits fire near the MA** (Stage-3/4
  transitions), *above* the red structural floor. So watch the exit dot land near
  the **black MA**, well above the red/magenta stops — that gap (peak → MA) is the
  give-back, and it shows the *binding* exit is the stage/MA roll-over, not the
  hard correction stop.

Rendered with `analysis/scripts/stage_chart` from the deep snapshot warehouse
(`/tmp/snap_top3000_1998_2026_v2`, via `dump_snap`). Price = adjusted_close (the
classifier's basis); entry/exit dots are placed on that line, so they may differ
from the backtest's raw fill price — the *timing* (vertical lines) and *stage
context* are the point. x-axis = week index within the window (not calendar).
Per-bar data in the sibling `.csv` files.

## The point these illustrate
The strategy's biggest drawdown is **not** crash risk — it's **give-back of
unrealized markup** on let-winners-run positions, because the trailing stop sits a
structural **~22% below price** (below the base / 30-week MA, by design, to avoid
being whipsawed out of real trends). A winner that runs up big rolls over and gives
back the *distance to the trailing stop* before a weekly close finally breaches it.
The stop caps the loss; it cannot lock in near the peak. That is the let-winners-run
tradeoff, not a bug (tightening it is WF-CV-rejected — it cuts the fat-tail winners
that are the whole edge).

## Give-back winners (ran up in Stage 2, rolled into Stage 3, gave back into the MA)
| chart | trade | peak (MFE) → realized | exit |
|---|---|---|---|
| `BELFA_2022-23_giveback.png` | 2022-01 → 2023-03 (416d) | +197% → +135% | stop_loss |
| `YPF_2022-23_giveback.png` | 2022-09 → 2023-03 (194d) | +125% → +60% | stop_loss |
| `AEO_2025-26_giveback.png` | 2025-08 → 2026-03 (203d) | +121% → +45% | laggard_rotation |
| `DSWL_2025_giveback.png` | 2025-07 → 2025-12 (147d) | +61% → +31% | stop_loss |
| `SIEB_2025_giveback.png` | 2025-05 → 2025-08 (98d) | +63% → +8% | laggard_rotation |

In each: a long green Stage-2 run with the black 30w-MA trailing well below; near the
right edge the green turns 🟠/🔴 and price falls back toward (and through) the MA —
the give-back. BELFA is the cleanest: ~$15 → ~$62 peak → back to ~$45.

## Whipsaw loser (fast V-top, stopped at a real loss)
| chart | trade | result |
|---|---|---|
| `ASTE_2024_whipsaw.png` | 2024-03 → 2024-05 (40d) | −21.7% stop_loss |

Stage-2 entry near ~$42, spike to ~$52, then a fast crater to ~$30 in weeks — too
fast for the MA to help; the stop fired at −21.7% (≈ the structural stop distance).
This is the *other* component of the 2024-25 bleed: many fresh entries stopped at
−13% to −22% in a choppy tape.
