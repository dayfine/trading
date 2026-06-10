---
name: project_trade_realism_liquidity
description: "Liquidity is a non-issue at our position sizes even at top-3000; breadth edge + cascade-inversion + fat-tail winners are all in liquid names. Don't prefer top-1000 on liquidity grounds."
metadata: 
  node_type: memory
  type: project
  originSessionId: 5fcb588e-0fe8-4d61-ac09-7315a7496370
---

User directive (2026-06-10): don't assume top-3000 = illiquid; we trade a modest
book, not millions — measure per-trade liquidity, grade realism, discount as
needed. **Answer: liquidity is a non-issue.**

Method: per round-trip trade, `position_usd = quantity×entry_price`; `adv_usd` =
20-day trailing mean of `close×volume` from bar store `data/<f>/<l>/<SYM>/data.csv`;
`liq_ratio = position/adv` = days-of-ADV. Cell-E $1M-init runs. Scripts in
`/tmp/liq_{analyze,summary,full}.sh`.

Findings (`dev/notes/trade-realism-liquidity-findings-2026-06-10.md`):
1. **Realized trades liquid on both breadths**: top-3000 91% of trades <0.1 days-ADV,
   only 1% (6 trades) >5d; top-1000 98%/<0.1d. Discounted aggregate (cap position at
   K days ADV) gives ≥100% of realized PnL on both (the few illiquid trades were net
   losers) — **edge survives realistic fills**.
2. **Fat-tail winners are in LIQUID names**: top-3000 top-12 winners all liq <0.04d
   (CALX +$779k @0.03d, etc.). Not thin-name fantasy.
3. **Cascade-inversion is NOT a liquidity artifact**: breakout median liq 0.010d vs
   early 0.0065d (both liquid); score-85/A+ picks the MOST liquid names (0.05d) yet
   worst win-rate (31.8%). The `w_early_stage2` reweight lever stands on its own.
4. **Terminal MTM is REAL + exitable** (reframes [[project_broad_universe_790_mtm_inflated]]):
   top-3000 ends $8.6M of which AXTI open position = $6.69M (78%). AXTI bars Verified
   — genuinely ran to $79→$96 on ~$983M/day volume; the $6.69M mark is 0.01 days-ADV,
   trivially exitable. NOT fantasy. Real concerns are **single-name concentration**
   (entry cap max_position_pct_long 0.14 not re-applied as a 36× winner balloons to
   78% NAV) + **unrealized** (never Stage-3/4 exited) — position-management, not
   liquidity.

Implications: don't prefer top-1000 over top-3000 on liquidity; re-weight the
"top-3000 edge = artifact" priors (rejections must rest on cross-breadth/per-fold
generalisation, not implicit "illiquid"). [[project_pit_survivorship_inflation]] is
about SURVIVORSHIP (separate, still valid), not liquidity. Liquidity-aware sizing is
LOW priority; a concentration/winner-trim guard is the more relevant risk lever.
