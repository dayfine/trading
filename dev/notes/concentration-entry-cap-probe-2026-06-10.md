# Concentration entry-cap probe — 2026-06-10

A config-only directional probe of the concentration-vs-return tradeoff
(`dev/plans/concentration-rebalance-2026-06-10.md`), run while the faithful
partial-trim mechanism is blocked on a core change (decision item). Varied the
**entry** cap `portfolio_config.max_position_pct_long` on top-3000-2011
(2011-2026, snapshot mode, $1M init), everything else Cell-E.

## Result

| `max_position_pct_long` | total return | MaxDD | Sharpe | win% | open-positions value |
|---|---|---|---|---|---|
| 0.07 | +116.5% | 23.9% | 0.440 | 30.5% | $2.14M |
| 0.10 | +140.2% | 26.0% | 0.442 | 32.0% | $2.27M |
| **0.14 (baseline)** | **~+761%** (equity $8.6M) | ~29% | — | 34.6% | $6.69M (AXTI alone) |

(Baseline MaxDD/Sharpe ~29% / ~0.71 from `project_n3000_covid_oom` /
`project_broad_universe_790_mtm_inflated`; the cap-variant runs captured full
metrics.)

## Reading

1. **The concentration largely *is* the return.** Halving the entry cap
   (0.14→0.07) cuts return ~6.5× (+761%→+116%) while improving MaxDD only ~5pp
   (29→24%). A terrible risk-adjusted trade — the fat-tail winners (AXTI etc.)
   need position *size* to drive the headline return; blunt down-sizing throws the
   edge away for a marginal drawdown gain. Sharpe is essentially flat across caps
   (~0.44), i.e. tighter sizing scales return and risk down together — no
   risk-adjusted improvement.

2. **This is the *entry*-cap — a pessimistic proxy for the trim mechanism.** An
   entry cap under-sizes a position from day one, so a 0.07 cap never lets AXTI
   build. A **partial trim** is fundamentally different: it lets the winner run to
   the cap (e.g. 25-50% of NAV) and trims only the *excess*, capturing most of the
   monster run while bounding further concentration. So the trim would sit far
   above these entry-cap returns.

3. **Design implication for the faithful trim (P0 decision item):** don't bound
   concentration aggressively — the monster upside is the edge. The trim cap
   should be **generous** (35-50%), trimming only *extreme* single-name
   concentration, not equal-weighting. The value proposition is **tail-risk
   insurance on the unrealised-mark + single-name-blowup scenario** (a held
   monster reversing before a Stage-3/4 exit fires), not a return enhancer. The
   experiment metrics should therefore weight **MaxDD / time-underwater / the
   realised-vs-unrealised split** over mean return, and accept a modest return
   give-up for a meaningful tail-risk reduction — if even a generous trim can't
   show that, concentration is simply the price of the strategy's edge and should
   be accepted (with the risk made explicit).

## Bottom line

Confirms the user's instinct twice over: (a) AXTI-style concentration is the
strategy working, not an artifact; (b) the refinement worth pursuing is a
*generous* partial-trim as tail-risk insurance — built on the core partial-exit
transition (decision item) — **not** a tighter entry cap, which is strictly
dominated.
