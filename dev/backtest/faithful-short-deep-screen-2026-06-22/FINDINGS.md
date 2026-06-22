# Faithful short (Build 3) — DEEP screen FINDINGS (2026-06-22)

The deep-regime re-screen the shallow 2010-2026 screen
(`dev/backtest/faithful-short-screen-2026-06-22/FINDINGS.md`) called for. Same 5
arms, but on a **survivorship-correct PIT universe across two real sustained
bears** — the dot-com bust (2000-02) and the GFC (2008) — the regimes where
Weinstein's short doctrine is supposed to earn its keep and which 2010-2026
(a secular bull) entirely lacked.

- **Universe:** `sp500-2000-01-01` PIT membership (515 names, incl. delisted
  LEH/BS/AIG etc.), **472/526 with bars fetched fresh from EODHD** (1998-2012,
  90% coverage; delistings retained at real death dates — LEH→2008-09-17 etc.).
- **Window:** 2000-01-01 → 2010-12-31, warmup from 1999-06-05. CSV mode, reads
  the gitignored repo-root `data/` store.
- **Arms:** identical overlay; only the two faithful-short flags vary (plus
  `enable_short_side=false` for the long-only reference).

## Headline — in real bears the short leg WORKS; the two gates split hard

| arm | flags | return | trades | MaxDD | Sharpe | Calmar | shorts (net $) |
|---|---|---|---|---|---|---|---|
| 00 long-only ref | short off | 327.1% | 392 | 31.6% | 0.917 | 0.446 | — |
| 01 baseline longshort | un-gated | **475.6%** | 401 | 27.6% | **1.066** | **0.624** | 18 (+$228.7K) |
| 02 neutral_blocks_shorts | Bearish-only | **475.6%** | 401 | 27.6% | **1.066** | **0.624** | 18 (+$228.7K) |
| 03 slow_grind_gate | slow-grind only | 367.1% | 397 | 26.7% | 0.962 | 0.563 | 5 (+$362.3K) |
| 04 both | Bearish + slow-grind | 367.1% | 397 | 26.7% | 0.962 | 0.563 | 5 (+$362.3K) |

Both long-short arms **beat long-only on return AND drawdown AND every
risk-adjusted metric**. The un-gated short leg adds **+148pp return** and cuts
**MaxDD 31.6→27.6** — Weinstein's short doctrine validated on a deep
survivorship-correct universe. (This corrects the bull-only-window impression —
2010-2026 and the #1678 NO-BUILD — that "shorts don't work": they work *in bear
regimes*; bull regimes squeeze them.)

## The two Build-3 flags have OPPOSITE verdicts

### `neutral_blocks_shorts` (Bearish-tape-only) — KEEPER, promote candidate
- **Bear regime (this screen): INERT.** 02 is identical to baseline (18 shorts,
  +$228.7K, 475.6%, Sharpe 1.066) — **every un-gated short was already in a
  Bearish tape**, so restricting to Bearish removes nothing.
- **Bull regime (shallow screen): HELPS.** It removed exactly the 5 early-2010
  Neutral-tape squeeze losses (−$33.7K) → +5.6pp, reverting to long-only.
- **Net: strictly helpful-or-inert across both regimes.** It removes the
  un-faithful (Neutral-tape) shorts and keeps every faithful (Bearish-tape) one.
  This is the regime-adaptive faithful short. → **escalate to WF-CV + promotion
  grid** (`experiment-gap-closing` → `promotion-confirmation.md`). Could be the
  first short-side mechanism to clear.

### `enable_slow_grind_short_gate` — TAXES the edge (reject-as-is / gate on Build 0)
- **Bear regime: HURTS risk-adjusted return.** It cuts the short book 18→5,
  dropping not just small losers but a profitable dot-com short (**JNS +$48.9K,
  2001**). Total return falls **475.6→367.1**, Sharpe **1.066→0.962**, Calmar
  **0.624→0.563** — for only a marginal MaxDD change (27.6→26.7). It does NOT
  pay for itself.
- **Bull regime: inert-equal-to-neutral** (removes all shorts, same as neutral).
- **There is no regime where slow-grind beats neutral.** It is a **winner-touching
  tax on the profitable short tail** — the short-side analog of
  [[project_edge_is_the_fat_tail]]. → **do not prioritize promoting it.** Revisit
  ONLY after Build 0 (A-D wiring): its over-restriction is the inert A-D-lead leg
  (`~ad_bars:[]`) forcing reliance on the strict weeks-below-falling-MA≥8 leg,
  which misses faster bear legs like much of 2008.

## The WHY (transferable deliverable)

1. **The short edge is itself a fat tail.** The un-gated short book's +$228.7K is
   dominated by **ONE** position: **GENZ shorted 2008-08-30 → 2009-03-18 for
   +$340.1K** (held through the GFC crash to near the bottom) — amid many small
   losers. The let-the-short-run monster IS the edge, exactly mirroring the long
   side ([[project_edge_is_the_fat_tail]]). Regime split of the 18: dot-com
   (≤2003) +$27.4K, GFC-era +$201.3K.
2. **Why slow-grind looks better per-trade but worse in total.** Its 5 kept
   shorts net MORE ($362K > $228K) because it drops small losers — but it also
   drops the JNS winner, and fewer shorts changes the long-book capital/exposure
   deployment under the caps (`max_long_exposure 0.70` / `min_cash 0.30`), and
   the un-gated config's long book captured more of the 2003-07 + 2009-10
   recoveries. Net: total return and risk-adjusted metrics are *worse*. (The
   long↔short capital interaction is a known attribution limit — shorts affect
   cash/exposure → long sizing. The robust ordering un-gated ≥ grind holds on
   every aggregate metric regardless.)
3. **Regime is the governing variable for the short leg** — consistent with
   [[project_factor_lens_regime_governs_edge]]. Shorts are additive in sustained
   bears, a drag (squeezes) in bulls. The right lever is a **macro/tape gate**
   (`neutral_blocks_shorts`) that turns the short leg off in non-bear tapes — NOT
   a decline-shape gate (`slow_grind`) that second-guesses *which* bear shorts to
   take and taxes the tail.

## Verdict (screen-rigor calibrated)

- **`neutral_blocks_shorts`: PROMISING — escalate to the real test.** Strictly
  helpful-or-inert across a bull and a bear regime; risk-adjusted-best in the
  bear regime; removes the loss-making bull shorts. This is a *promotion-track*
  decision, not a promotion — WF-CV + the macro-regime-diverse confirmation grid
  decide the default flip.
- **`enable_slow_grind_short_gate`: NO-BUILD-PRIORITY decision (not a rigorous
  rejection).** On this deep screen it taxes the bear short edge and never beats
  `neutral`; combined with the fat-tail prior that's enough to deprioritize it.
  Only a WF-CV surface can *reject* it; hold it as a default-off axis, gated on
  Build 0 making its A-D leg live.

## Caveats / infra

- **Single deep window + survivor-leaning large-cap PIT** (sp500-as-of-2000, 90%
  coverage). Conservative for short *profits* (survivors recovered), so the
  measured +148pp short benefit is if anything understated. Still one window —
  the promotion grid (`promotion-confirmation.md`) must add ≥1 more
  (period × universe) cell before any default flip.
- Long↔short capital-interaction confound on the *total*-return attribution
  (point 2) — direct short P&L and the aggregate-metric ordering are both clean.
- `all_eligible` diagnostic post-step errored on the universe path (looks under
  `data/` not `test_data/` — the same fixtures-root bug noted in the shallow
  screen); main `actual.sexp` metrics are valid.
- Deep bars fetched into the gitignored `data/` store via
  `dev/scripts/fetch_deep_2000.sh` — not committed (experiment input).
