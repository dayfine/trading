# Faithful short (Build 3) — screen FINDINGS (2026-06-22)

> **SUPERSEDED on the benefit question** by the deep re-screen
> `dev/backtest/faithful-short-deep-screen-2026-06-22/FINDINGS.md` (2000-2010,
> survivorship-correct 472-name PIT). The deep screen shows the short leg DOES
> work in real bears (+148pp, lower DD), splits the two Build-3 flags
> (`neutral_blocks_shorts` = keeper/promote-track; `slow_grind_gate` = taxes the
> edge), and supplies the "keep half" this bull-only window could not.
>
> **Correction (2026-06-22):** the universe-coverage caveat below originally said
> "309/510 names have committed bars" — that counted the wrong store
> (`trading/test_data/`). The runner reads the gitignored repo-root `data/`,
> which at run time held deep history for only **~25 mega-cap survivors**, so the
> effective universe here was **25 mega-caps** (AAPL…XOM), not 309. This makes
> the screen even *less* able to surface Stage-4 shorts (mega-caps rarely top out)
> — which is exactly why only 5 shorts occurred. The verdict (NEEDS-DEEP-DATA) is
> unchanged and strengthened.

Read-only screen of the Build-3 mechanism (`Weinstein_strategy.config`
`neutral_blocks_shorts` + `enable_slow_grind_short_gate`; merged #1696,
both default-off). Question: does tightening shorts to confirmed bears
(Bearish tape) and/or slow-grind declines flip the short leg from a
net-negative drag (squeezed on fast-V bounces) to a contributor?
Screen-rigor per `.claude/rules/mechanism-validation-rigor.md`.

Scenarios: `trading/test_data/backtest_scenarios/experiments/faithful-short-screen-2026-06-22/`
(00-longonly-reference, 01-baseline-longshort, 02-neutral-only,
03-grind-only, 04-both) on `universes/sp500-historical/sp500-2010-01-01.sexp`,
CSV mode, 2010-2026. Overlay config copied verbatim from the
`sp500-2010-2026-longshort` golden — the ONLY thing varied across arms is the
two faithful-short flags (plus `enable_short_side=false` for the long-only ref).

## Headline — the gates admit ZERO shorts; all three revert to long-only

| arm | flags | return | trades | win% | MaxDD | Sharpe | Calmar |
|---|---|---|---|---|---|---|---|
| 00 long-only ref | short off | **53.46%** | 291 | 38.5 | **10.63%** | 0.498 | 0.250 |
| 01 baseline longshort | un-gated short | 47.87% | 296 | 37.8 | 12.89% | 0.456 | 0.188 |
| 02 neutral_blocks_shorts | Bearish-tape only | 53.46% | 291 | 38.5 | 10.63% | 0.498 | 0.250 |
| 03 slow_grind_gate | slow-grind only | 53.46% | 291 | 38.5 | 10.63% | 0.498 | 0.250 |
| 04 both | Bearish + slow-grind | 53.46% | 291 | 38.5 | 10.63% | 0.498 | 0.250 |

`actual.sexp` AND `trades.csv` are **md5-identical** across 00/02/03/04. Each
faithful gate reduces the short book to **zero** → the long-short collapses
exactly onto long-only. Only the un-gated baseline (01) differs.

## What the un-gated short leg actually was: 5 early-2010 squeeze losses

The entire un-gated short book on 2010-2026 = **5 SHORT trades, all in
Feb-Aug 2010, all Stage-4 entries, all stopped out (squeezed), net −$33,684**:

| symbol | entry | exit | days | pnl$ | pnl% | exit |
|---|---|---|---|---|---|---|
| ADBE | 2010-02-13 | 2010-02-18 | 5 | −1,496 | −0.78 | stop_loss (gap_down) |
| JPM | 2010-02-20 | 2010-03-03 | 11 | −6,437 | −3.94 | stop_loss (intraday) |
| BAC | 2010-02-20 | 2010-03-11 | 19 | −6,112 | −9.33 | stop_loss (gap_down) |
| UNH | 2010-05-22 | 2010-08-04 | 74 | −10,405 | −13.74 | stop_loss (gap_down) |
| COST | 2010-05-22 | 2010-05-28 | 6 | −9,233 | −5.22 | stop_loss (gap_down) |

These are residual post-GFC Stage-4 names shorted into the **2009-2010 V-recovery
rip** — every one squeezed out at a stop. They (plus their portfolio-state ripple
on the longs) cost the baseline **−5.6pp total return and +2.3pp MaxDD** vs
long-only. The faithful gates remove all 5.

## Verdict: NEEDS-DEEP-DATA (mechanism SAFE + faithful; benefit untestable here)

Not a rejection, not a promotion. Calibrated per screen-rigor — a proxy window
that cannot exercise the mechanism's intended benefit:

- **SAFE / faithful (confirmed).** The gates correctly remove exactly the
  un-faithful, loss-making shorts (early-2010 recovery squeezes). At worst they
  neutralize a money-losing leg; they never add a losing short. Spine intact
  (`weinstein-faithful-core.md` W1) — they only tighten the short admission gate.
- **Benefit UNCONFIRMABLE on 2010-2026.** The hypothesis was "the slow-grind /
  Bearish gate keeps profitable 2000-02/2008-style sustained-distribution shorts
  while skipping V-squeezes." This window has **no such slow-bear regime** — the
  only shorts that ever occurred were the early-2010 squeezes, which the gate
  rightly skips. There were 0 confirmed-Bearish-tape stock shorts to keep. So the
  screen confirms the *skip* half of the thesis but cannot test the *keep* half.

The mechanism stays **default-off + an axis** (no promote, no reject), exactly
mirroring the fast-crash-stop screen (`dev/backtest/fast-crash-stop-screen-2026-06-22`).

## The WHY (transferable deliverable)

1. **The gate decision is macro/index-driven, hence universe-independent.**
   `neutral_blocks_shorts` keys off the ^GSPC macro tape; `slow_grind_gate` keys
   off the ^GSPC decline character. So "the gate opened on 0 short-bearing weeks"
   is robust to the universe — the gate's open/close is the same regardless of
   which names are loaded.
2. **2010-2026 is a secular bull with no sustained distribution bear.** 161
   Bearish weeks existed (mostly brief: 2011, 2018-Q4, 2020-V, 2022) but produced
   zero qualifying stock-level Stage-4 shorts under the gate — the bear windows
   were too short/sharp to be `Slow_grind`, and (with `~ad_bars:[]`, A-D inert)
   the slow-grind leg leans entirely on weeks-below-falling-MA ≥ 8 + shallow rate,
   which a V-crash never satisfies.
3. **The un-gated short edge here was negative by construction** — Weinstein
   shorts squeezed on a V-recovery. This re-derives `project_edge_is_the_fat_tail`
   from the short side: an un-gated short leg in a bull regime is a tail-RISK
   *cost*, and the faithful gate is the tail-RISK *insurance* that removes it.

## Forward guidance (capitalize the finding)

- **The benefit test requires a slow-bear regime — re-screen on 2000-02 + 2008.**
  Build the deep universe via the `fetch-historical-data` skill +
  `dev/scripts/build_deep_universe.sh` (top-500/1000 PIT, 1998-2010), then re-run
  these 5 arms over a window spanning the dot-com bust + GFC. Only there can the
  gate demonstrate it KEEPS profitable sustained-bear shorts. This is the same
  deep-data unblock the fast-crash screen needs — fetch once, serves both.
- **Do NOT promote on this window.** A "no-drag" result on a bull window is the
  *necessary* safety check, not the *sufficient* benefit case
  (`promotion-confirmation.md` — needs a macro-regime-diverse grid cell covering
  2000-02 + 2008).
- **A/D wiring (Build 0) sharpens the slow-grind leg.** With `~ad_bars:[]` the
  classifier's A-D-lead leg is inert, so `Slow_grind` currently fires only on the
  weeks-below-falling-MA leg. Build 0 (wire `Ad_bars.load` into `pipeline.ml:103`)
  would let the gate catch distribution tops earlier — relevant to the deep
  re-screen.

## Caveats / infra

- **Decimated universe: 309/510 SP500 names have committed bars** (39% missing,
  store cleaned). The baseline short *count* (5) is therefore a lower bound — a
  full universe might surface a few more Stage-4 shorts. But (a) the gate decision
  is universe-independent (point 1), and (b) the qualitative finding (un-gated
  bull-regime shorts lose; gates remove them) is robust. A clean-data re-baseline
  is nice-to-have, not load-bearing for this verdict.
- The `all_eligible` diagnostic post-step errored (looked for the universe under
  `data/` not `test_data/` — a fixtures-root path bug in the all-eligible emitter,
  not the main backtest). Main metrics (`actual.sexp`) are valid.
- Shorts surface in `trades.csv` as explicit `side=SHORT` rows here (5 of them);
  the older "shorts invisible as Sell→Buy round-trips" note (weinstein_strategy.mli)
  did not apply to this run.
