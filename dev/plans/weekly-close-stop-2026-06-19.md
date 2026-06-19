# Weekly-close stop confirmation — a lens-driven stop improvement (2026-06-19)

**Origin:** user insight 2026-06-19, off the decision-grading deep stop read
(`dev/experiments/decision-grading-deep-2026-06-18/FINDINGS.md`). The
insurance decomposition showed `stop_loss` forgoes **more** upside (+30-33% mean)
than the disaster it dodges (−19% mean) → net per-decision value-add −6 to −9%.
The user's point: *that gap is improvement room* — the stop is whipsaw-dominated,
and a stop that fired less on noise would forgo less upside while still catching
genuine Stage-4 rollovers.

## Confirmed mechanism

The live stop is a **GTC broker stop checked every day on the bar low**
(`stops_runner._trigger_fill_price` → `bar.low_price` for longs;
`Weinstein_stops.check_stop_hit` doc: "Long: triggered by `low_price ≤
stop_level`"; the runner comment: "the GTC stop sits in the market every day").
So an **intra-week shakeout wick** below the stop triggers an exit even when the
week *closes* back above it — the classic shakeout. This is a deliberate
broker-realism model, not a bug.

Weinstein's actual rule (book §Stop-Loss Rules; the qc-behavioral **L3** contract
"Stop triggers on weekly close below stop level, not intraday") is **weekly-close
confirmation**: only act if the *Friday weekly close* is below the stop; ignore
intra-week lows. That directly targets the foregone-upside the lens measured.

## The dial (spine-faithful, default-off)

Add `stop_trigger_on_weekly_close : bool [@sexp.default false]` to the stops
config (`experiment-flag-discipline` R1: default reproduces the current
intraday-GTC behaviour bit-for-bit; R2: a real config field → `Variant_matrix`
axis). Spine item #5 (stop below base/MA) is untouched — only the *trigger
confirmation* changes, which is itself the book's L3 rule, so this is a faithful
dial, not a spine change (`weinstein-faithful-core` W1/W2).

When true:
- Non-Friday bars: no intraday trigger (skip `_handle_stop_trigger_only`'s check).
- Friday bar: trigger on `close_price` vs stop (a close-based `check_stop_hit`
  variant), not the week's low. Fill at the close (or next open), not the low.

## The honest risk (what the test must measure)

Weekly-close trades whipsaw-avoidance for **deeper fills on genuine breakdowns**:
in a real Stage-4 collapse the Friday close can be well below where an intraday
stop would have filled. So the lens's `disaster_dodged` (−19%) will change — that
is exactly what re-grading measures. The foregone upside is *also* partly the
fat-tail recovery, so a looser exit that recaptures it can also ride genuine
collapses further down. Per-decision improvement need not be portfolio
improvement.

## Disciplined test arc

1. **Implement** the default-off flag (TDD; feat-weinstein scope; `weinstein/stops`
   + `stops_runner`). Default-off → all goldens replay bit-identical.
2. **Lens screen** (read-only, the cheap before/after): re-run the deep 1998-2026
   + 2011 Cell-E with the flag on, re-grade with `decision_grading` →
   does `stop_loss` mean **upside-foregone shrink** while **disaster-dodged**
   holds, and net value-add improve? Also top-level return/Sharpe/MaxDD vs
   long-only deep. (`screen-rigor`: distribution, not point estimate; calibrate
   the verdict — a screen can say "promising, escalate" or "no-build", not
   "proven".)
3. **If promising → WF-CV** (`experiment-gap-closing`) as a `Variant_matrix` axis
   `((flag stop_trigger_on_weekly_close) (values (true false)))` with Deflated
   Sharpe + Pareto.
4. **Promotion-confirmation grid** (`promotion-confirmation.md`): robust across
   ≥3 (period × universe) cells incl. a bear-dominated macro regime, before
   flipping the default. Never promote on a single-window win.

## Why this is a good lever (not the entry-selection dead end)

Unlike entry/swap selection (which the lens + `project_accuracy_is_unreachable`
show is a coin flip), the stop *trigger model* is a structural mechanic with a
clear, faithful, book-backed alternative and a measurable whipsaw cost. It is a
holding-discipline / tail-preserving lever (`project_edge_is_the_fat_tail`:
"bias to tail-PRESERVING levers — holding discipline"), not a winner-touching
tax. The decision-grading lens is the instrument that surfaced it and will judge
it.
