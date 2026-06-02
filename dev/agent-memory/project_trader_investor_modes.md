---
name: project_trader_investor_modes
description: "Weinstein trader vs investor = config presets (MA 10wk/30wk etc.). RESULT 2026-06-01: 10wk trader REJECTED on SPY (strictly worse both windows — faster MA amplifies whipsaw). Investor 30wk = drawdown-insurance sweet spot; selection (Cell E) >> timing. PR #1401 dial."
metadata:
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

**Design (2026-05-31, user decision):** Weinstein's trader vs investor distinction
is a **bundle of config dial-values applied to ONE parameterized strategy**, not
two code modules. Confirmed against the book text (the user's PDF). Plan:
`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`. Governed by
[[feedback_weinstein_faithful_core]].

**The preset delta** (every value already in or natural to our config):
| dial | investor (built) | trader |
|---|---|---|
| stage MA period | 30-week | 10-week |
| entry mode | initial base breakout | continuation (pullback-to-MA + re-breakout) = `enable_continuation_buys` |
| sizing | scale-in (½/½) | full size on breakout |
| exit | Stage 3→4 | earlier, at Stage-3 onset |
Book: 30wk-investor/10wk-trader explicit (p.~15); "The Trader's Way" continuation
buy + "home run on the breakout" (Ch.3); "traders get out as Stage-3 top forms"
(Ch.2).

**Reframes the program's 3 rejections:** continuation-buys, early-admission,
hysteresis are all **trader-mode dials** — we only ever tested them grafted onto
the 30wk INVESTOR base, one knob at a time, on SP500. We NEVER tested the coherent
trader preset (10wk + continuation + early exit, together). The rejections only
say "don't half-graft" — trader-mode-as-a-whole is untested.

**RESULT — trader 10wk REJECTED (2026-06-01, ma_period_weeks dial PR #1401).**
Ran the full 4-mode × 2-window matrix on the SPY testbed
([[project_spy_reference_strategy]]; writeup `dev/notes/spy-mode-comparison-2026-06-01.md`):

| | Bull 2009-2026 (ret/trades/win/DD) | Deep 2000-2026 |
|---|---|---|
| BAH-SPY | 619%/0/–/34% | 370%/0/–/55% |
| **Investor 30wk** | 318%/10/70%/18.8% | **420%/19/47%/18.8%** |
| Trader 10wk | 187%/28/14%/27% | 172%/46/24%/30% |
| Cell E (SP500) | ~Sharpe 0.94 (15y) | **2379%/820/36%/23%** |

**The 10wk trader is strictly worse than the 30wk investor on BOTH windows** —
~3× the trades, ~⅓ the win rate, HIGHER drawdown, ~half the return; loses even to
BAH on the deep window. The faster MA AMPLIFIES whipsaw (exits every minor dip,
re-enters every minor bounce — death by a thousand cuts), it does not fix it. The
"re-enter closer to the V-bottom" intuition is overwhelmed by noise sensitivity.
**For index timing, 30wk dominates 10wk. Do not pursue faster MA for whipsaw
reduction — it does the opposite.** (Caveat: tested the MA-period dial IN
ISOLATION, not Weinstein's full trader *package* — continuation entries + early
exits + sizing — which is meant for individual stocks, not index timing.)

**Two bigger findings from the matrix:** (1) Investor 30wk is the drawdown-insurance
sweet spot (18.8% MaxDD both windows; beats BAH on the deep window via the dot-com +
GFC favorable round-trips — at the GFC bottom held 2.4× BAH's capital). (2)
**Selection ≫ timing:** Cell E (multi-symbol picker) returned 2379%/$24.8M on deep,
4.8× the SPY timer — stock selection captures dispersion the index can't. The
ma_period_weeks dial stays a default-off axis; rejection recorded. Writeups:
`dev/notes/spy-stage-timing-trades-2026-05-31.md`, `spy-deep-window-2026-05-31.md`,
`spy-mode-comparison-2026-06-01.md`.
