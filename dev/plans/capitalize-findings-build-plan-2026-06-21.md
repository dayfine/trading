# Capitalize-on-findings build plan — 2026-06-21 (queued for next session)

**Governing principle (user directive 2026-06-21):** Don't outright-reject a lever.
**Mine every analysis finding for what worked vs what didn't, then direct the
system to AVOID the weakness and DOUBLE DOWN on the strength.** A rejection is only
done when its transferable *why* has been converted into a positive build directive
(refines `mechanism-validation-rigor.md` §"the real deliverable is the why" and
softens the reflexive-reject posture of `edge_is_the_fat_tail`).

## The night's findings, sorted into strength vs weakness

| | STRENGTH (double down) | WEAKNESS (avoid / gate out) |
|---|---|---|
| Engine | Crash-protection: beats S&P over full cycles by dodging 2000-02 + 2008 (+421% vs S&P −7% in the crash decade) | Bull-lag: badly lags S&P in sustained bulls (+130% vs +631%, 2009-26) |
| Floor (SPY-timing) | Reliable cash defense — half the drawdown (24% vs 57%); dodges crashes without squeeze risk | Whipsaw cost: lags S&P BAH even in bulls (+318 vs +631) |
| Barbell | Light floor (0.30-0.40) keeps ~90% of return AND cuts DD 48%→35-39% | Fixed weight is a regime-averaging compromise (optimal differs crash vs bull) |
| Shorts | **Work in SLOW grinding bears** (2002 +$145k, 2008 +$277k) | **Squeezed in FAST V-recoveries** (2020 −$520k across 4 re-shorts) + supply-gated |
| Stops / laggard | Laggard rotation = the long-side profit engine | Stop whipsaw is a structural cost |

## The load-bearing insight: SLOW vs FAST is detectable BEFORE the decision

Shorts (and aggressive bear-defense generally) **pay in slow grinding declines and
get squeezed in fast V-crashes.** The naive worry is this needs lookahead — but
**Weinstein's own breadth framework distinguishes them in real time:**

- **Distribution-driven slow bears** (2000, 2008): the **A/D line peaks 5-10 months
  BEFORE the index top** (book Ch. 8 / macro section: "A-D line peaks 5-10 months
  before the DJI" — 1961/1965/1972/1987 examples). Breadth deteriorates for months
  → the decline is broad, grinding, *short-able*.
- **Shock-driven fast-V crashes** (2020 COVID, 1987 one-day): **no breadth warning**
  — the drop is exogenous and snaps back fast → shorting it gets squeezed.

So the **decline-character / regime-speed gate** is a *faithful, lookahead-free*
feature: did this decline come with a multi-month A/D-divergence lead (→ grind,
defend hard / short), or out of nowhere (→ V, don't short, minimal whipsaw)?
We already compute A/D breadth bars; this reuses them.

## Build / improve items (all default-off experiments first, per flag-discipline)

### P0 — Operationalize the validated barbell (double down on the proven strength)
1. **Finish the overlay end-to-end wiring** — the #1683 follow-up: the
   `scenario_runner` flag + the two leg-thunk builders so the barbell runs end-to-end
   (config + blend core + tests already landed). `[non-blocking]`
2. **Pin the light floor weight (0.30-0.40)** via WF-CV + `promotion-confirmation.md`
   grid on the CORRECT window (1998-26 full + 1998-2008 grind + 2009-26 bull +
   a top-1000/3000 breadth cell). The frontier is known; this certifies the weight.

### P1 — Faithful Weinstein short, GATED on decline-character (give the book a fair shot + capitalize slow-vs-fast)
The book *advocates* shorting; our two tests were **unfaithful** (index-short = wrong
instrument; #1678 individual-short maybe ungated). Owe it a fair test:
1. **Verify #1678's short-leg gating** (read code): did it require confirmed **market
   Stage-4**, or fire in any regime? Determines whether the NO-BUILD was even fair.
2. **Build the decline-character feature** (slow-grind vs fast-V), default-off:
   classify the current decline from the **A/D-divergence lead** + rate-of-decline +
   weeks-below-declining-MA. No lookahead. Reuse existing breadth bars.
3. **Faithful short screen**, default-off: individual Stage-4 shorts, gated on
   (a) confirmed market Stage-4, (b) negative + deteriorating RS, (c) minimal nearby
   support, (d) buy-stop ~10-15% / never-above-rising-MA, **and (e) slow-grind
   decline-character** (the new gate — skip fast-V). Run 1998-26, decompose by bear
   window (2000-02, 2008, 2022 grind = expect pay) vs 2020 V (expect *correctly
   skipped*). Screen first (`screen-rigor`), then WF-CV if promising.
   - **Hypothesis:** the slow-grind gate flips the short leg from net-negative
     (−$50k, squeezed) to net-positive by *avoiding the V-squeezes* while keeping
     the 2002/2008 wins. If it doesn't, the modern-regime V-recovery verdict stands —
     but now *measured*, not asserted.
   - **Headwinds to state up front:** supply is bear-gated (intermittent overlay, not
     a continuous leg); modern Fed-driven V-recoveries squeeze harder than Weinstein's
     1960-87 slow bears.

### P2 — Bull-participation (the engine's known weakness — faithful levers only, low expectation)
Bull-lag is structural and 10wk-MA "fixes" it only as an MTM mirage (#1682). Honest
options, each a default-off screen:
- In **confirmed strong bulls** (broad A/D thrust, index Stage 2 sustained), does a
  **less-twitchy exit** (hold through shallow corrections) recover bull
  participation without giving back the crash-protection? (Exit-aggressiveness dial,
  test as a coherent preset, not a knob.)
- Or accept the bull-lag as the *price* of crash-protection and let the **floor**
  carry bulls (it already beats the engine in bulls). Likely the honest answer.

### Meta — encode the process directive
Add a `feedback`-type memory: "capitalize findings — avoid weakness, double down on
strength; a rejection isn't done until its *why* is a positive build directive."
Applies to every screen/experiment writeup going forward.

## Sequencing
P0 first (operationalize the sure thing) → P1 (the decline-character gate is the
novel, high-interest build; it's also the bridge that could rescue the short leg) →
P2 (lower expectation). All default-off; main stays shippable.
