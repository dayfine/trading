# Fast circuit-breaker SPY sleeve — design (P1b of the floor-quality program)

**Status: DESIGN (no code).** Drafted 2026-07-08 PM session, per
`next-session-priorities-2026-07-08-PM.md` P1b and the user steer recorded in
`memory/project_floor_quality_program`: *"timed SPY is worse than SPY; if we
can have a better timed SPY (long-only with a quick and accurate circuit
breaker), that by itself is more valuable as the floor sleeve."*

## Goal and success bar

A long-only SPY floor sleeve that:

1. **Matches TOTAL-RETURN SPY over the full window** (2000-2026). The
   comparator is adjusted-close / dividend-inclusive SPY — never raw close
   (standing rule, 2026-07-08).
2. **Cuts the left tail**: materially reduces the deep crash drawdowns
   (2000-02, 2008, 2020, 2022) without giving the savings back in whipsaw.

Explicitly NOT the bar: Calmar / Sharpe optimization. The 70/30 barbell
already showed the blend frontier buys Calmar at ~55pp/26y per 10pp of floor
(`barbell-on-stocks-2026-06-02.md`); the program scoreboard is absolute
return + start-date robustness.

## Why the existing timed-SPY floor fails the bar

`Spy_only_weinstein_strategy` is full Weinstein stage timing on SPY: enter
Stage 2, exit Stage 3→4 rollover or trailing stop. Deep 2000-2026: 386.9% /
18.8% DD vs BAH-SPY 394% **raw close** — i.e. it loses to raw-close SPY and
loses harder to TR-SPY. Two structural reasons:

- **It times everything.** Stage exits fire in ordinary chop, not just
  crashes. Every false exit is an upside tax on the one instrument whose
  long-run drift is the whole return. (The index sleeve's "winner" IS the
  buy-and-hold position — per `project_edge_is_the_fat_tail`, touching it
  needs the tail-RISK-insurance exception, which means rare, crash-gated
  interventions only.)
- **Both its exit and its re-entry wait for weekly-MA confirmation.** In a
  fast V (2020) the MA rolls over weeks after the crash (exit at the bottom)
  and confirms re-entry weeks after the bottom (miss the rebound). The
  factor-lens finding (realized edge ~ forward index DD, r=−0.79) says the
  value of being out is concentrated in a few forward-DD regimes — everything
  else is drag.

Design consequence: **default-in-market; the breaker is a rare intervention,
asymmetric by decline character, with fast re-entry.**

## Signal inventory (all already built, all config-gated)

| ingredient | what it gives the breaker |
|---|---|
| `Decline_character.classify` (#1692) | `Fast_v` / `Slow_grind` / `Not_declining` on the index, pure + lookahead-free |
| `fast_v_ignores_ma_filter` (#1708) | arming speed: rate-alone fast-V detection before the MA confirms (the 2020 fix) |
| A-D-live breadth (`project_ad_default_flip`) | breadth-led distribution detection — the confirmed short-TIMING edge; feeds `Slow_grind` via the A-D-lead leg |
| catastrophic-stop machinery (#1695) | precedent for an absolute-drop trigger armed only on `Fast_v` |
| factor-lens r=−0.79 | evidence that forward-DD regimes are detectable enough to be worth gating on |

## Breaker state machine (proposal)

Two states, `In_market` / `Out_of_market`, evaluated at DAILY cadence (weekly
cadence is the source of the 2020 lag; the whole point is speed).

**Exit triggers (any one fires → sell to cash):**

- **T1 fast-crash rate**: index drawdown over a short trailing window ≥
  `fast_exit_rate_pct` (decline-character `Fast_v` semantics with
  rate-alone arming — no MA precondition).
- **T2 breadth-led distribution**: `Slow_grind` classification (A-D line
  leading the index down) sustained `grind_confirm_weeks` — the slow bear is
  where early exit pays (2000-02, 2008); confirmation cost is low because the
  decline itself is slow.
- **T3 absolute floor**: index close below `(1 − floor_drop_pct) ×`
  **trailing-window high** — the catastrophic backstop.

**Re-entry triggers (asymmetric by which exit fired):**

- After **T1/T3 (fast crash)**: fast re-entry — index recovers
  `fast_reentry_recover_pct` off the post-exit low (or above a short MA),
  DAYS cadence. A V-bounce missed is the floor's biggest historical tax.
- After **T2 (slow grind)**: Weinstein-style re-entry (price above a turning
  weekly MA). Grind bottoms are slow; confirmation is cheap there.

**Semantics requirements (the GME lesson — MUST-HAVE, from
`warmup-364-repin-2026-07-08.md` §Findings):**

1. **The peak is an INDEX-PRICE trailing-window high, never a monotonic NAV
   high-water mark.** `Force_liquidation.Peak_tracker` is monotonic over NAV;
   one position's parabolic MTM spike (GME Jan-2021, $28.9M peak) set a floor
   the run could never re-clear → 32 repeat liquidations, strategy dead for 5
   years. An index-referenced, windowed peak decays by construction and
   cannot be poisoned by position-level MTM. (For a single-SPY sleeve
   NAV≈index anyway, but the interface must be index-referenced so the
   breaker generalizes to the engine side without inheriting the pathology.)
2. **No halt-until-macro-flip.** Re-entry is self-contained in the state
   machine. The engine `Portfolio_floor`'s Bearish→non-Bearish reset is the
   second half of the GME sterilization (reset fires, NAV still under the
   un-decayed floor, refires). The engine-side fix is decision item 2 in the
   handoff (human call) — separate from this sleeve.

## Build shape (when mandated — default-off per experiment-flag-discipline)

- **Pure breaker lib** in `analysis/weinstein/macro/` (e.g.
  `index_circuit_breaker.ml`): `state → weekly/daily index view → A-D macro →
  state * action`. Pure, lookahead-free, all thresholds in a config record —
  same pattern as `Decline_character`.
- **Thin sleeve strategy** alongside `Spy_only_weinstein_strategy` (build
  alongside, don't modify): buy-and-hold SPY + breaker consumption. Sizing
  all-cash like the BAH benchmark.
- Every threshold above is a config field → `Variant_matrix` axis on day one
  (R2). Nothing hardcoded.
- **Adjusted-close bars for both the sleeve and the comparator** — out-of-
  market periods forgo dividends and that cost must be counted honestly.

## Evaluation plan (in order)

1. **Lens screen vs TR-SPY, 2000-2026** (cheap, read-only after build):
   full-window return + per-episode table (2000-02, 2008, 2011, 2015-16,
   2018Q4, 2020, 2022): drawdown captured vs avoided, days out of market,
   number of interventions (should be SMALL — single digits per decade),
   per-intervention whipsaw cost distribution (not just the mean, per
   `mechanism-validation-rigor`).
2. **WF-CV as a surface** (`experiment-gap-closing`): trigger thresholds as
   axes; Deflated Sharpe; fold gate.
3. **Promotion grid** (`promotion-confirmation`): must include a deep
   bear-regime cell (2000-02 + 2008) — a bull-only grid can only certify a
   bull artifact.
4. Only after a floor beats TR-SPY-with-smaller-tail: **P1c blending**
   (barbell gates un-park).

## Open questions (human input welcome, not blocking design)

- Threshold priors: `fast_exit_rate_pct` — decline-character's
  `fast_v_min_rate_pct` default is 0.08/4wk; the breaker likely wants a
  faster window (daily rate). Start the surface wide.
- Should T2 (slow-grind exit) also partially de-risk (e.g. 50%) instead of
  binary exit? Binary first — fewer knobs, honest read; partial is a
  follow-on axis.
- Sleeve instrument: SPY price bars + adjusted for comparator, or trade
  adjusted series directly? Needs a data-layer check on dividend handling in
  the simulator before build.
