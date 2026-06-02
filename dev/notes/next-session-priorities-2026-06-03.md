# Next-session priorities — 2026-06-03

**Supersedes:** `next-session-priorities-2026-06-02-PM2.md`. That doc's arc (sector
rotation → macro gate → barbell → "breadth is the lever") is **done and extended this
session into the individual-stock world**: the ETF lab was used to attribute mechanisms,
then the production strategy was run on a clean point-in-time S&P 500 to test whether the
selection edge transfers. This doc is the forward plan from those results.

## The through-line this session

The ETF work (sector rotation, macro gate, barbell) was a **feature-attribution lab**.
This session pointed the validated recipe at **individual stocks** on a trustworthy
universe, and the headline flipped from the earlier (stale-pin) reading:

> **Selection transfers as a RETURN engine, not as a risk-adjusted winner. Simple SPY
> index-timing beats full-machinery stock-picking on Calmar in BOTH regimes.** The
> bankable edge is the drawdown floor; selection is a return engine bolted on top — the
> barbell decomposition, now confirmed on stocks.

## Headline results — production strategy on clean PIT S&P 500

Universe: `universes/sp500-historical/sp500-{2000,2010}-01-01.sexp` — Wikipedia
membership-replay (`wiki_sp500`), **survivor-bias-free** (includes index exits), ~full bar
coverage (507/510 for 2010). Production = full Cell E config (0.14/0.70/0.30 sizing +
stage3-force-exit h=1 + laggard-rotation h=2 + macro gate). All returns **raw close**
(the strategy trades raw close, so BAH is raw too — see Correction 3).

| | bull 2010-26 Ret/DD/Calmar | deep 2000-26 Ret/DD/Calmar |
|---|---|---|
| BAH-SPY (raw) | 534% / 34% / ~0.35 | 394% / 56% / ~0.11 |
| **SPY-only** (index timing) | 337% / 18.8% / **0.48** | 420% / 18.8% / **0.35** |
| **Production** (stock selection) | 237% / 17.5% / 0.44 | **918%** / 37% / 0.25 |

- **Selection adds a lot of return** (deep: 918% vs index ~420%) and **dominates buy-and-hold**
  (918% > 394% *and* 37% DD < 56% DD). It is a strong strategy.
- **But it pays in drawdown** (deep 37% vs SPY-only's 18.8%) — individual names crash
  harder than the index; the macro gate + diversification don't fully protect.
- **On the LOCKED objective (Calmar / drawdown-defense), SPY-only index-timing wins both
  regimes** (0.48/0.35 vs 0.44/0.25). Return vs risk-adjusted is a **mandate choice**, not
  a defeat — and the barbell (blend floor + engine, ~70/30) is how you get both.

## Three corrections this session (all from running/computing, not trusting a number)

1. **Deployment ≠ what I claimed.** SPY-only is already ~67-78% in-market (not badly idle);
   rotation adds only +9-12pp. The return uplift of multi-symbol over single-symbol is
   ~⅔ **selection**, ~⅓ deployment — not "rotation fills idle cash." (`autopsy-gap-accounting-2026-06-02.md`)
2. **GSPC golden drift.** The pinned sp500-2010-2026 = 341%/Calmar 0.52 was measured with
   the GSPC index golden floored at 2017 → the **macro gate was degenerate 2010-2017**.
   #1380/#1383 fixed the floor; corrected number is **237%/0.44**. The golden's bands were
   never updated → **it is STALE and now FAILs** (loose end below).
3. **Dividend basis.** The strategy trades **raw close** (no dividends); my first BAH was
   adjusted-close (748%). Fair raw BAH: bull 534%, deep 394%. Relative comparison (both
   raw) is apples-to-apples; absolute returns are price-only floors.

## Autopsy gap accounting (`autopsy-gap-accounting-2026-06-02.md`, #1427)

The 2026-05-29 autopsy gap (+1557 late_reentry / +1176 false-stage3 / +505 late-admission)
was reproduced exactly. **Its prescribed cures (hysteresis / exit-timing / early-admission)
all failed WF-CV → ~0% closed via its own mechanisms.** The gains we banked came from
**selection + deployment + downside control** — axes the per-symbol autopsy can't even
measure. No single "% closed" is extractable (per-symbol blindness + non-CAGR-convertible).

## Stage-classifier visual diagnostic (NEW capability + finding)

Built `analysis/scripts/stage_chart/` — renders a symbol's weekly close **colored by its
programmatic Weinstein stage** over the 30w MA, via `owl-plplot` → PNG, which I can view
directly. First chart (SPY 2005-2010, a textbook Stage 2→3→4) **visually confirms the
autopsy**: the classifier sprinkles **false Stage-3 (topping) flags mid-advance while price
is still clearly above a rising MA**, and mis-reads a 2008 bear-rally as Stage 2 (a buy
mid-GFC).

**Key redirect:** because the false Stage-3 flips happen *while price is still above the
MA*, the principled fix is **price-action confirmation (don't call Stage 3 until price
actually crosses below the MA)** — NOT the weeks-based hysteresis that WF-CV already
rejected. Calibrating to the *chart* (visual ground truth) sidesteps the return-overfit
that killed the blind tuning. Caveat: n=1 so far; the tool makes scanning more
symbols/eras cheap.

## What's next (prioritized)

### P0 · Barbell-on-stocks blend (cheap, resolves the 918%-vs-DD tension)
The most interesting open question: can you keep most of the 918% deep-window selection
return while pulling the 37% DD back toward the 18.8% floor? Post-hoc 50/50 + 70/30 NAV
blend of the **SPY-only floor + the production engine** (same `/tmp/blendw.awk` method as
the ETF barbell), bull + deep. Needs both equity curves on the same window (re-run SPY-only
deep + reuse the production deep curve). This is the direct payoff of the whole arc.

### P1 · Few-feature carrier comparison (feature attribution on stocks)
Does lighter machinery / macro-gate-off shift the return/DD tradeoff, or is the DD cost
inherent to stock selection? Adapt `Sector_rotation_weinstein` to **consume the scenario
universe** (it currently hardcodes the 11 SPDR ETFs) + sweep **K much higher** (10/20/30 —
3-of-510 is reckless) + add a **sector cap**. Run on PIT S&P 500, compare to production.
This is the most build-heavy item.

### P2 · Stage-classifier price-action-confirmation fix
Scan more symbols/eras with `stage_chart` to confirm the false-Stage-3 pattern generalizes,
then implement a **price-below-MA confirmation gate** for the Stage-2→3 transition (a
config dial, default-off per flag-discipline). Test against the per-symbol autopsy harness
(missed-gain buckets) AND visually. This is the less-overfittable revival of the rejected
exit-timing fix.

### P3 · Widen toward mid/small-cap (now unblocked by min_price #1428)
Once selection is characterized on clean S&P 500, widen to PIT top-1000/3000 **with the
`min_price` floor (1/5/10) + an ADV floor** — the bankable broad-universe test that the
top-3000 result (penny-stock-flattered) could not be.

## Loose ends (clean these early next session)
- **STALE GOLDEN:** `goldens-sp500-historical/sp500-2010-2026.sexp` bands assume the
  pre-GSPC-fix 341%; it now FAILs (corrected ~237%). Re-pin to the corrected numbers
  citing #1380/#1383. Quick golden/docs PR. (It's local-only / not in CI, so it didn't
  surface — local goldens drift silently; consider a periodic local re-pin sweep.)
- **`stage_chart` tool**: committed this session (see git log) OR on a branch — verify it
  landed; it's a keeper.
- Scratch to remove: `test_data/backtest_scenarios/_pit_*`, `dev/backtest/scenarios-2026-06-02-*`,
  `/tmp/*.svg /tmp/*.png`, `stage_spy_gfc.png` at repo root.

## Data / tooling state (ready)
- **PIT S&P 500 universes**: `universes/sp500-historical/sp500-{2000,2005,2010,2015,2020}-01-01.sexp`
  — survivor-bias-free, ~full bar coverage. The clean narrow universe.
- **min_price floor** (#1428): merged; default-off; settable via
  `((screening_config ((min_price 5.0))))` scenario override. Gates on setup price.
- **stage_chart bin**: `analysis/scripts/stage_chart/bin/stage_chart.exe <SYM> <START> <END> <DATA_DIR> <OUT.png>`.
- **RAM**: container ~6GB; 510-sym production run ~3.5GB (bull) / ~4.5GB (deep) → `--parallel 1`,
  purge `/tmp/panel_runner_csv_snapshot_*` between runs.

## Ramp-up reminders
- Step 0: main CI green; newest priorities = this doc.
- Code PRs: `gh pr merge --admin --squash`; confirm MERGED before deleting branch.
- Serialize backtests vs jj agents. Bounded poll loops only (`for i in $(seq …)` + break,
  never bare `until` — see `feedback_bounded_poll_loops.md`, violated twice this session).
- The locked objective is **drawdown-defense / risk-adjusted** — but "918% with 37% DD"
  is a legitimate higher-return mandate; the barbell is how you reconcile them.
