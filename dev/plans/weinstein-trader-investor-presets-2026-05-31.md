# Weinstein trader vs investor presets — design + first experiment

**Status:** DESIGN + first experiment spec (2026-05-31). Source: Stan Weinstein,
*Secrets for Profiting in Bull and Bear Markets* — confirmed against the book
text (the user's PDF) this session. Reference: `docs/design/weinstein-book-reference.md`.

## The design decision

**Trader and Investor are not two strategy modules — they are two named config
presets of the SAME parameterized strategy.** Every distinguishing value already
exists (or has a natural home) in our config. This fits the codebase's
"every parameter in config, never hardcoded" rule and keeps one code path.

| Knob | **Investor** preset (what we built) | **Trader** preset | Config home |
|---|---|---|---|
| Stage MA period | **30-week** | **10-week** | `Stage.config` ma_period |
| Entry mode | initial Stage 1→2 base breakout | **continuation** (advance → pullback to MA → re-breakout) | `enable_continuation_buys` |
| Early-Stage-2 buying | more (patient, near base) | less | emergent |
| Sizing | scale-in (½ on breakout, ½ on pullback) | **full size on breakout** ("home run"), fast profit, repurchase on pullback | sizing config |
| Exit timing | hold to Stage 3→4 | **earlier — get out as the Stage-3 top starts forming** | `stage3_force_exit_config` |
| Holding horizon | up to 12 months | "each significant 2–4 month move" | emergent |

Book citations (the user's PDF): 30-week-for-investors / 10-week-for-traders
(p.~15); "The Trader's Way" continuation buy (Ch.3); "purchase your entire
intended position on the breakout… home run for a trader" (Ch.3); "once a Stage 3
top starts to form, traders should get the heck out" (Ch.2).

So `weinstein-investor.sexp` and `weinstein-trader.sexp` become two pinned config
sexps run through the same strategy code and the same SPY testbed. Nothing new to
invent — a re-parameterization.

## The governing principle — Weinstein-faithful core

**Strictly follow Weinstein's strategy/methodology; adapt details only to the
extent the core stays intact.** Operationalized as spine vs dials:

**The spine (NEVER adapt — this IS the strategy):**
- Stage classification off the weekly MA (30 or 10-week); buy ONLY in Stage 2;
  on a breakout above resistance WITH volume confirmation; sell in Stage 3/4;
  initial stop below the base / below the MA; macro gate + sector gating;
  relative-strength for selection. Change any of these → it is no longer Weinstein.

**The dials (adapt freely — Weinstein himself parameterizes these):**
- MA period (he gives 10 vs 30 explicitly), entry mode (base vs continuation —
  both his), sizing (scale vs full — both his), exit aggressiveness (both his),
  and numeric thresholds tuned for the modern regime — his own caveat that
  program trading "made [the gyrations] even wilder" licenses regime adaptation.

This guardrail constrains the experiment search space to **Weinstein-faithful
configurations and faithful adaptations**, not an arbitrary knob-soup. It is the
antidote to the over-exploration the program has repeatedly warned against
(`feedback_strategy_mechanic_changes_too_explorative`).

## How this reframes the program's three rejections

Continuation-buys (#1366 combined-axis), early-admission (deep-rejected
2026-05-31), and stage3-hysteresis were all killed **as bolt-ons grafted onto the
30-week INVESTOR base, one knob at a time, on the SP500.** But they are
**trader-mode components.** We have NEVER tested the *coherent trader preset*
(10-week + continuation + early Stage-3 exit + full-size entry, together) against
the investor preset. The rejections only say "don't half-graft trader-parts onto
an investor body" — they say nothing about trader-mode as an integrated,
Weinstein-faithful strategy. **That is the untested and principled experiment.**

## First experiment — investor preset vs trader preset on the SPY testbed

Once the SPY reference strategy merges (PR #1397):

1. Define `weinstein-investor.sexp` (= the current SPY strategy config) and
   `weinstein-trader.sexp` (the trader-preset deltas above) as two pinned configs.
2. Run BOTH on the SPY testbed across **two regimes**:
   - **2009-2026** (bull + fast V-dips) — where the 30-week investor preset
     whipsawed (10% round-trip win rate, final NAV < BAH-SPY).
   - **Deep 2000-2026** (dot-com -49% + GFC -57%) — needs the deep-SPY fetch
     (`build_deep_universe.sh` / `fetch-historical-data`; the autopsy already ran
     SPY 1998-2025, so it's available).
3. **Metric = the compounding thesis, not just drawdown:** final NAV (capital
   preserved across each round-trip compounds), round-trip win rate, and
   exit-price-vs-subsequent-re-entry-price per trade — alongside Sharpe/Calmar/
   MaxDD and BAH-SPY. The hypothesis: the 10-week trader preset exits sooner
   (higher) and re-enters sooner (lower), realizing the favorable round-trip the
   lagging 30-week MA misses on fast dips — and the gap vs BAH should be largest
   on the deep window (two genuine 100→50→100 events to dodge).
4. Ledger each preset×regime cell per the gap-closing loop; the deep cell is
   mandatory (`.claude/rules/promotion-confirmation.md`).

## Connection to population search

The population-search apparatus (`dev/plans/population-search-2026-05-31.md`)
gets its anchor here: **the arms are Weinstein-faithful presets** (investor,
trader, and documented variants), not arbitrary configs. The spine/dials
principle defines the boundary of a legitimate arm. This makes the discrete
feature space principled and finite instead of an open knob-soup.
