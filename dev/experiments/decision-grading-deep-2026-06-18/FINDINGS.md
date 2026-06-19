# Decision-grading — deep multi-regime read + the stop-insurance question (2026-06-18)

Follow-on to `dev/experiments/decision-grading-first-report-2026-06-18/`. Two things:
1. Upgraded the lens to **decompose the exit's net continuation into its benefit
   (disaster dodged = post-exit max-adverse) and cost (upside foregone =
   post-exit max-favorable)** — the mean-continuation number alone can't tell a
   pure tax from cheap insurance.
2. Ran it across two regimes to answer: **does stop-loss earn its keep by
   avoiding disasters?**

Runs (same Cell-E config, only the window differs):
- **2011-26 bull** — top-3000 PIT-2011, `/tmp/snap_top3000_2011_v2`, +790.5% / 671 trades / 29.2% MaxDD.
- **1998-26 deep** — top-3000 PIT-1998 (adds dot-com bust + GFC), `/tmp/snap_top3000_1998_2026_v2`, +1934.5% / 1061 trades / 48.7% MaxDD.

Grade horizon 26w (the longer horizon captures more of the avoided decline than 13w; deep disasters still run past 26w, so the benefit below is if anything *under*-counted).

## The stop-loss decision, both regimes (grade horizon 26w)

| metric | 2011-26 bull | 1998-26 deep |
|---|---|---|
| n stops | 440 | 746 |
| mean realized | −2.8% | −1.2% |
| mean disaster dodged (max-adverse) | −18.9% | −19.5% |
| mean upside foregone (max-favorable) | +32.7% | +29.9% |
| mean post-exit continuation | +9.4% | +6.2% |
| **mean net value-add (= −cont)** | **−9.4%** | **−6.2%** |
| disaster-dodge rate (≤−20% drop dodged) | 40% | 36% |
| continuation p10 / p90 | −24.5% / +36.4% | −29.5% / +41.4% |

### Answer to "did we grade the disaster-avoidance benefit?"

Now yes. And the answer is nuanced:

- **Stops do avoid real disasters, regime-robustly.** ~36-40% of stops sat out a
  ≥20% further drop; the average stopped name fell ~−19% below the exit at its
  worst over the next 26 weeks (p10 −24% to −30%). The insurance is real, not
  imagined.
- **But the per-decision opportunity cost exceeds the per-decision benefit in
  BOTH regimes.** Net value-add is −9.4% (bull) / −6.2% (deep): on average,
  holding 26 more weeks would have beaten stopping. The benefit (−19% dodged) is
  outweighed by the upside foregone (+30-33%), because broad-universe names
  *recover* — the stop mostly fires on temporary dips, not permanent losses.
- **The bear-heavy regime narrows the gap but does NOT flip it** (−9.4% → −6.2%).
  Dot-com+GFC makes more of the dodged drops "stick," so stops look better than
  in a pure bull tape — but the fat-tail recovery still dominates the mean. This
  re-derives `project_edge_is_the_fat_tail` from the exit side: the broad-universe
  return is the right-tail recoverers, and a stop taxes them.

## The load-bearing caveat — why this is NOT "remove/loosen stops"

The lens measures **per-decision, equal-weight** opportunity cost. It is blind to
the **portfolio-path** role of a stop: capping one position's loss so a single
Stage-4 collapse can't take the whole NAV down. "Stops cost −6.2% per decision on
average" says nothing about the left tail of the *portfolio* return, which is the
actual reason stops exist. A per-trade equal-weight mean cannot price portfolio
ruin-avoidance. So:

- **Do NOT conclude "remove stops."** That changes the portfolio left tail this
  lens does not observe. It is a winner-/risk-touching strategy mechanic →
  `weinstein-faithful-core` (stop-below-base is spine item #5; only the *buffer*
  is a dial) + `experiment-flag-discipline` + WF-CV + the confirmation grid.
- **"Tune stops better" is a legitimate but low-priority hypothesis.** The
  decomposition says stops fire on recoverers (whipsaw-dominated), so a *looser/
  later* stop or a *post-stop re-entry* would recapture foregone upside. But
  stop-distance is already tuned (`installed_stop_min_pct = 0.08`, axis-1 winner)
  — expected marginal gain is small, and it touches the spine. Per
  `project_accuracy_is_unreachable_diversify_instead`, the better use of effort is
  a *diversifying layer* (long-short), not more exit-tuning.

## Other decision types (deep, 26w)

| exit_reason | n | mean realized | net value-add | disaster dodged | upside foregone | dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 296 | +16.9% | −4.7% | −15.9% | +21.6% | 29% |
| stage3_force_exit | 16 | +0.1% | +2.2% | −22.0% | +14.0% | 38% |
| stop_loss | 746 | −1.2% | −6.2% | −19.5% | +29.9% | 36% |

- **laggard_rotation** still houses the fat-tail winners (mean realized +16.9%);
  its net value-add went slightly negative deep (−4.7%) — rotating out of names
  that then ran — but it remains the profit channel by realized P&L.
- **stage3_force_exit** is the only net-positive exit decision (+2.2%), with the
  largest mean disaster dodged (−22.0%) and smallest upside foregone (+14.0%) —
  i.e. it fires on genuine Stage-3 tops that roll over, exactly as intended.
  Small n (16) but directionally Weinstein-faithful and the cleanest "good exit"
  in the book.

## Forward guidance (the transferable why)

1. The strategy's edge is the right-tail recoverers; **every winner-touching exit
   taxes it**, which is why stops and laggard-rotation both show negative
   per-decision net value-add. stage3_force_exit is the exception because it
   targets the *left*-tail rollovers specifically.
2. **Stop-tuning is near-exhausted and spine-constrained** — deprioritize.
3. **Bias the next lever to a diversifying layer (long-short, Initiative B)** that
   adds an offsetting return stream rather than re-touching the long exits.
4. Lens limitation to fix if exits become the focus: add a **portfolio-path /
   ruin-weighted** exit metric so the stop's true (tail-insurance) value is
   measurable, not just the per-decision opportunity cost.
