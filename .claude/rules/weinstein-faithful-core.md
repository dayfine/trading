# Weinstein-faithful core — the spine/dials guardrail

**Strictly follow Weinstein's strategy and methodology; adapt details only to the
extent the core stays intact.** This is the governing principle for all strategy
work and the experiment program. It constrains the search space to
Weinstein-faithful configurations and faithful adaptations of them — not an
arbitrary knob-soup. It is the antidote to the over-exploration the program has
repeatedly been burned by (`feedback_strategy_mechanic_changes_too_explorative`,
the hysteresis / continuation / early-admission rejections).

Source of authority: `docs/design/weinstein-book-reference.md` (the distilled
decision rules) and Stan Weinstein, *Secrets for Profiting in Bull and Bear
Markets*.

## The spine — NEVER adapt (change any of these and it is no longer Weinstein)

1. **Stage classification off the weekly MA.** Every instrument is in exactly one
   of Stages 1–4, determined by price vs a weekly moving average, the MA slope,
   and prior-stage context. (The MA *period* is a dial — see below — but the
   stage framework itself is the spine.)
2. **Buy ONLY in Stage 2.** No long entries in Stage 1, 3, or 4.
3. **Entry on a breakout above resistance WITH volume confirmation.** Not on price
   alone; volume expansion is required.
4. **Sell in Stage 3 / Stage 4.** Exit as the stock tops and rolls over; never
   ride a Stage 4 decline.
5. **Initial stop below the base / below the MA.** Risk is defined at entry by the
   base low or the MA, not an arbitrary percentage divorced from structure.
6. **Macro gate + sector gating are unconditional filters.** A bearish macro tape
   blocks buys; sector relative strength gates candidates. (Degenerate for a
   single-instrument index strategy like SPY-only — there the macro gate is the
   instrument itself, so it collapses to a no-op, which is faithful, not a
   violation.)
7. **Relative strength for selection** (multi-symbol): rank by RS vs the market,
   not absolute performance.

## The dials — adapt freely (Weinstein himself parameterizes these)

- **MA period.** He gives **30-week for investors, 10-week for traders**
  explicitly (daily for very short-term traders). Changing the period is faithful.
- **Entry mode.** Initial base breakout (investor) vs **continuation / pullback
  re-breakout** (trader, "The Trader's Way") — both his.
- **Sizing.** Scale-in (½ on breakout, ½ on pullback — investor) vs **full size on
  the breakout** (trader, "home run") — both his.
- **Exit aggressiveness.** Hold to Stage 3→4 (investor) vs **get out as the Stage-3
  top starts forming** (trader) — both his.
- **Numeric thresholds** tuned for the modern regime. Weinstein's own caveat that
  program trading "made [the day-to-day gyrations] even wilder" licenses adapting
  threshold values for a faster, choppier market than 1988 — *provided the spine
  is untouched*.

## Trader vs Investor are two config PRESETS, not two strategies

The trader/investor distinction is a **bundle of dial values** applied to the one
parameterized strategy — not two code paths. See
`dev/plans/weinstein-trader-investor-presets-2026-05-31.md` for the preset table.

## What QC / agents can check

For any PR that adds or changes strategy logic:

- **W1 — spine intact.** The change does not alter any spine item (1–7 above). A
  PR that, e.g., buys outside Stage 2, drops volume confirmation, or removes the
  macro gate is a FAIL regardless of backtest numbers.
- **W2 — adaptation is a dial, and config-expressed.** Any adaptation is one of
  the listed dials, lands as a config field (per `experiment-flag-discipline.md`),
  and cites Weinstein authority (book reference section) for why it is faithful.
  A mechanism that is *not* a documented dial or a faithful adaptation of one is
  out of scope — it must be justified against the book, not invented.
- **W3 — experiments are Weinstein-faithful presets.** Population-search arms and
  promotion candidates are presets/variants within this space, not arbitrary
  configs (`dev/plans/population-search-2026-05-31.md`).

## Why this is load-bearing

The program's three big rejections (continuation-buys #1366, early-admission deep,
stage3-hysteresis) were all *trader-mode dials grafted one-at-a-time onto the
investor base*. That is neither faithful (it mixes two presets incoherently) nor
how Weinstein frames them. This rule prevents that failure mode: adapt a dial only
within a coherent preset, keep the spine fixed, and test presets as wholes.
