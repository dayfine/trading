# Trade-realism / liquidity grading — plan — 2026-06-10

**User directive (2026-06-10, overnight):** "I don't necessarily agree that
top-3000 means illiquid… we are not trading millions of dollars — we should check
the volume data and market cap etc of our trades, and grade them based on the
'realistic-ness' of the trades and apply a score / discount as needed — but
otherwise I don't think it's responsible to simply prefer top-1000 over top-3000."

This corrects a standing assumption (`project_pit_survivorship_inflation`,
`project_broad_universe_790_mtm_inflated`, the laggard/force-exit rejections) that
top-3000 aggregate edges are "fat-tail artifacts" to be discounted. The principled
test is **per-trade liquidity realism**, not universe size.

## The question

For each trade the backtest took, could we **realistically** have filled the entry
and (more importantly) the exit at the modelled price, given the stock's actual
traded volume — when deploying a *modest* book (not millions)? If yes, the trade's
P&L is real and broad-universe breadth is a legitimate advantage. If the position
is large vs the stock's daily dollar-volume (ADV), the fill is fantasy and that
trade's contribution should be **discounted**.

## Metric

Per trade:
- `position_usd = quantity × entry_price` (capital deployed; grows with NAV as the
  book compounds — this is the crux, since a $100k book that compounds to $8M puts
  $1M+ into single names).
- `adv_usd` = trailing ~20-trading-day average of `close × volume` (raw shares),
  computed **before** entry (and separately before exit, since exit liquidity is
  what lets you realise the gain).
- `liq_ratio = position_usd / adv_usd` = **days-of-ADV** the position represents.
  - `< 0.1` trivially fillable (a fraction of one day's volume).
  - `0.1–1` fine (fill over part of a day to a day).
  - `1–5` marginal (needs several days to enter/exit without large impact).
  - `> 5` unrealistic for a price-taker — exiting moves the market; the modelled
    exit price is not achievable.

Market cap is a secondary lens (size class), but **ADV dollar-volume is the
load-bearing liquidity proxy** and we have it directly (bars carry `volume`).
Shares-outstanding / market-cap is not in the bar store, so ADV is primary.

## Two deliverables

### (A) Realism evaluation lens (this session's focus)
A per-run report: distribution of `liq_ratio`, the **PnL-weighted** share of
return coming from each liquidity bucket, and a **discounted aggregate** that caps
each trade's size at a realistic fraction of ADV (e.g. recompute return as if no
position exceeded `K × adv_usd`, scaling the trade's dollar-PnL by
`min(1, K·adv/position)` as a first-order impact-free haircut). Re-run the
top-3000 / top-1000 / top-500 comparison under the discount. **Decision it
informs:** does the top-3000 breadth edge survive realistic fills, or is it
concentrated in unfillable thin names? Specifically re-check the AXTI-style monster
winners (`project_broad_universe_790_mtm_inflated`).

### (B) Liquidity-aware position sizing (candidate mechanism, follow-on)
If (A) shows thin-name fills inflate the edge, the *fix* is Weinstein-faithful: cap
position size at a fraction of ADV (a real liquidity constraint Weinstein
respects — he trades liquid leaders). A new default-off config dial
`max_position_adv_days` (or `max_position_pct_adv`) that clamps the order to a
realistic size. Default-off / no-op per `experiment-flag-discipline`; tested via
WF-CV. This could be a *better* lever than the cascade reweight, and it directly
answers the user's "apply a score/discount as needed."

## Build

OCaml, no Python. Prototype is `/tmp/liq_analyze.sh` (awk over `data/<f>/<l>/<SYM>/
data.csv`, columns `date,open,high,low,close,adjusted_close,volume,active_through`;
$-vol = `close × volume`). Productionize as a forensics library
`trade_liquidity` + bin under `trading/trading/backtest/`, joining `trades.csv`
to the bar store, mirroring `trade_audit_report`'s structure (pure `render` +
`to_markdown` + `load`), with tests. Fits the trade-forensics workstream
(`dev/notes/trade-forensics-2026-06-09.md`).

## Preliminary finding (top-1000, 2026-06-10)

Top-1000 is liquidity-clean: **94% of trades < 0.01 days-of-ADV**, 98% < 0.1d,
1 trade > 5d; every top-10 winner is in a liquid name (< 0.01d). So at top-1000
the modelled returns are realistic — liquidity is not where the top-1000 vs
top-3000 difference lives. The open question is whether **top-3000** introduces a
meaningful tail of unfillable thin-name trades. (Top-3000 regen + analysis pending.)
