# Trade-realism / liquidity findings — 2026-06-10

**Directive (user, overnight 2026-06-10):** don't assume top-3000 = illiquid; we
trade a modest book, not millions. Check actual volume / market-cap of our trades,
grade realism, discount as needed — don't simply prefer top-1000 over top-3000.

**Answer: liquidity is a non-issue at our position sizes, even at top-3000. The
breadth edge is NOT a liquidity artifact, and neither is the cascade-selection
inversion. Preferring top-1000 over top-3000 is not justified by liquidity.**

## Method

For each round-trip trade in a run, `position_usd = quantity × entry_price`, and
`adv_usd` = trailing 20-trading-day mean of `close × volume` (raw shares) from the
bar store (`data/<f>/<l>/<SYM>/data.csv`). `liq_ratio = position_usd / adv_usd` =
**days-of-ADV** the position represents. Bucketed: `<0.1` trivial, `0.1–1` fine,
`1–5` marginal, `>5` unrealistic for a price-taker. Discounted aggregate scales
each trade's $-PnL by `min(1, K·adv/position)` (a first-order, impact-free haircut
simulating a position cap at `K` days of ADV). Runs are the canonical Cell-E
backtests (2011-2026, snapshot mode), `$1M` initial capital. Scripts:
`/tmp/liq_analyze.sh`, `/tmp/liq_summary.sh`, `/tmp/liq_full.sh`.

## Result 1 — realized trades are liquid on BOTH breadths

| bucket (days-of-ADV) | top-1000 | top-3000 |
|---|---|---|
| `<0.1` (trivial) | 98% | 91% |
| `0.1–1` | 1% | 7% |
| `1–5` (marginal) | 1% | 2% |
| `>5` (unrealistic) | 0% (1 trade) | 1% (6 trades) |
| max ratio | 6.8 d | 41 d |

Top-3000 has a slightly longer tail (6 unrealistic trades vs 1) but it is tiny.
**Discounted aggregate** (cap each position at K days of ADV):

| cap | top-1000 | top-3000 |
|---|---|---|
| K=0.1d | 191% of realized | 105% of realized |
| K=1.0d | 152% | 105% |
| K=5.0d | 113% | 101% |

Capping positions at a realistic fraction of ADV gives **≥100% of realized PnL on
both breadths** — because the few illiquid trades were net *losers*. **The edge
survives realistic fills; discounting does not threaten it — it slightly helps.**

## Result 2 — the fat-tail winners are in LIQUID names

Top-3000 top-12 winners by $-PnL, all with `liq_ratio < 0.04 days` (one at 0.77d):
CALX (+$779k, 0.03d, $257k position), DEG (+$472k, 0.035d), BVN (+$328k, 0.029d),
BKE, GPN, DQ, AUY, AMED, AMD ($421k position, 0.000d), … The monster winners are
**not** thin-name fantasy — they are realistically fillable positions in names
doing tens of millions to ~$1B/day.

## Result 3 — the cascade-inversion is NOT a liquidity artifact

| | breakout | early |
|---|---|---|
| median liq (days) | 0.010 | 0.0065 |
| win% | 33.8 | 42.2 |

Both stage-kinds are liquid; the win-rate gap is not a fill effect. By score: the
**highest** cascade score (85 / A+) picks the **most liquid** names (mean 0.05d)
yet has the **worst** win-rate (31.8%); score-70 (early) is *less* liquid (0.63d)
but best win-rate (45.9%). So the scoring-reweight lever
(`w_early_stage2`, PR #1512/#1513) stands on its own — it is a genuine selection
signal, not a liquidity confound. The 6 `>5d` trades are all small losers (foreign
ADRs CELJF/ASMIY, etc.).

## Result 4 — the terminal MTM is REAL and exitable (reframes prior "inflation")

The top-3000 run ends at **$8.6M equity** of which **one open position, AXTI, is
$6.69M (78%)**. Prior conclusion (`project_broad_universe_790_mtm_inflated`) called
the +790% "MTM-inflated artifact." The liquidity lens corrects this: **AXTI's bars
are Verified** — it genuinely ran to ~$79 (→$96 by May 2026) on **~$983M/day**
dollar-volume. The $6.69M position is **0.01 days of ADV** (0.7% of one day's
volume) — trivially exitable. The terminal mark is a **real, capturable unrealized
gain, not thin-name fantasy.**

The genuine concerns about it are therefore **(a) single-name concentration** (78%
of NAV in one name — the entry cap `max_position_pct_long 0.14` is applied at entry
but not re-applied as a winner appreciates, so a 36× winner balloons to 78% of
NAV), and **(b) it is unrealized** (the strategy held to the backtest end and never
executed a Stage 3/4 exit). Both are position-management questions, not liquidity.

## Implications

1. **Do not prefer top-1000 over top-3000 on liquidity grounds.** Top-3000 returns
   are realistic at our scale; breadth = more genuine opportunities.
2. **Re-weight the "top-3000 edge = artifact" priors** that drove the
   laggard / force-exit / stage2-ma-hold rejection framing. The breadth edge is
   real on realized + liquid trades; rejections should rest on cross-breadth /
   per-fold generalisation, not an implicit "illiquid" assumption.
   (`project_pit_survivorship_inflation` is about *survivorship* in the SP500
   composition golden — a separate, still-valid concern — not about *liquidity*.)
3. **Liquidity-aware position sizing (deliverable B) is LOW priority** — there is
   almost no unrealistic trade to clamp. A **concentration / winner-trim** guard
   (cap ongoing single-name NAV %, or a Weinstein Stage-3 trim) is the more
   relevant risk lever, and is its own experiment.
4. **The cascade-reweight (`w_early_stage2`) WF-CV is still warranted** — the
   inversion is a real selection signal, independent of liquidity.

## Caveats / next

- `liq_ratio` uses a 20-day trailing ADV; a stress version would use ADV *during*
  the actual exit week and a participation cap (e.g. ≤10%/day → days-to-exit).
- A productionised OCaml `trade_liquidity` tool (reads the snapshot/CSV bar store,
  emits per-trade realism grades + a discounted aggregate, mirroring
  `trade_audit_report`) is worth building to make this a repeatable lens — but
  given liquidity is a non-issue at current scale, it is secondary to the
  concentration/winner-management finding.
