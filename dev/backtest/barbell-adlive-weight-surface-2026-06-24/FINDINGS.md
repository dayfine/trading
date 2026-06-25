# Barbell weight surface on the A-D-live basis + long-short engine — 2026-06-24

First barbell weight surface measured on the **A-D-live** default basis (#1725), and
the first to include a **long-short** engine leg. Settles the open barbell weight
mandate (`project_barbell_on_stocks`): every prior weight grid (06-02, 06-20, 06-21)
was on the A-D-**inert** basis with a **long-only** engine.

## Basis (one fixed comparison surface)

- Window 2000-01-01 → 2026-04-30; universe `sp500-historical/sp500-2000-01-01` (515
  PIT names, delisting-correct); current A-D-live code; CSV mode on repo-root `data/`.
- Three legs, only the engine short-flag + the blend weight vary:
  - **FLOOR** = `Spy_only_weinstein (SPY, ma=30wk)`, long/flat index timing —
    **386.9% / 18.8% MaxDD / Sharpe 0.575** (matches the prior barbell floor 387%/18.8%).
  - **ENGINE-LO** = Cell-E, `enable_short_side=false` — **871.0% / 27.4% DD / 0.718**.
  - **ENGINE-LS** = Cell-E, `enable_short_side=true` (same overlay) — **721.7% / 25.3% DD / 0.675**.
- Post-hoc constant-weight daily-return NAV blend (`blend.awk`), `w` = SPY-floor fraction.

## The two surfaces (same scale)

`w_floor` | LO ret% / Sharpe / MaxDD% / Calmar | LS ret% / Sharpe / MaxDD% / Calmar
---|---|---
0.0 (pure engine) | 871 / 0.718 / 27.4 / 0.319 | 722 / 0.675 / 25.3 / 0.319
0.3 | 718 / **0.744** / 21.9 / 0.368 | 631 / 0.720 / 19.3 / 0.394
0.4 | 667 / 0.742 / 19.9 / 0.390 | 597 / **0.724** / 17.2 / 0.431
0.5 | 617 / 0.733 / 18.0 / 0.417 | 563 / 0.720 / 15.7 / **0.459**
0.6 | 568 / 0.715 / 16.6 / **0.436** | 528 / 0.707 / 15.9 / 0.441
0.7 (70/30) | 520 / 0.690 / 16.6 / 0.418 | 493 / 0.684 / 16.1 / 0.421
0.8 | 474 / 0.657 / 16.6 / 0.399 | 457 / 0.653 / 16.3 / 0.400
1.0 (pure floor) | 387 / 0.575 / 18.8 / 0.319 | 387 / 0.575 / 18.8 / 0.319

(LO and LS share the w=1.0 endpoint = pure floor; they diverge most at w=0 = pure engine.)

## What the short leg does (the transferable why)

1. **The short leg is a drawdown-reducer, not a return-adder.** At *every* weight LS has
   **lower return AND lower MaxDD** than LO (pure engine: −149pp return, −2.1pp DD). It
   adds no new winning stream — it shaves the engine's drawdowns at a return cost. This
   is the A-D-live short-timing signature (`project_ad_default_flip`: helps risk-timing,
   costs bull return) and consistent with `project_edge_is_the_fat_tail` (the edge is the
   long fat tail; shorts are insurance, not alpha).
2. **Shorts and the SPY floor are partial substitutes** — both reduce drawdown. Turning
   shorts on shifts the Calmar-optimal floor weight *down* (LS peak Calmar 0.459 @ w=0.5
   vs LO 0.436 @ w=0.6) and to a lower DD (15.7 vs 16.6%): the shorts already do part of
   the floor's job, so less floor is needed.
3. **LO keeps the better Sharpe peak and more return at every weight** (LO 0.744 @ w=0.3
   vs LS 0.724 @ w=0.4). The short leg's modest Calmar lift comes purely from DD, not
   risk-efficiency.

## Weight read (corrects the stale "70/30")

On the A-D-live basis both surfaces peak **lighter than 70/30**: Sharpe-optimal ~0.3–0.4,
Calmar-optimal ~0.5–0.6. The earlier "70/30 robust" was an A-D-inert / weak-engine-window
artifact; the light-floor read from the 1998-26 work (`engine-edge-1998-2026`) holds here.

## DECISION: pure engine (w=0), no barbell floor

Per user direction 2026-06-24: **pure engine is fine** — keep the full engine upside; do
not deploy a SPY floor. The barbell's only benefit is drawdown reduction bought with a
real return give-up (e.g. 70/30 LO = 520% vs 871% pure, for 27.4→16.6% DD), and the
internal engine machinery (stage3 force-exit + laggard rotation) plus the now-live A-D
macro gate already supply crash defense. The short leg likewise is not adopted: it only
trades return for DD (a partial floor substitute), and shorts stay **default-off** (the
faithful tail-tool status from the decline-character program). **Barbell weight mandate
is resolved: no floor; long-only pure engine is the production stance.**

This closes P2 (barbell weight cert) from `next-session-priorities-2026-06-24.md`.

## Caveats
- Deep-run absolute returns carry some terminal-MTM inflation (`project_broad_universe_790`),
  but LO-vs-LS and the weight-shape are on one identical basis → the *relative* read and
  the optimal-weight shape are robust.
- Post-hoc constant-weight blend (no rebalancing cost / no deployable overlay) — adequate
  for the weight decision, which came out "no floor."
- Legs/curves: `/tmp/barbell-adlive/` scenarios; equity curves under
  `dev/backtest/scenarios-2026-06-25-012007/{engine-lo,engine-ls}` +
  `scenarios-2026-06-25-022146/spy-only-deep` (gitignored runner output).
