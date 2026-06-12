# Long-short margin mechanics — broker/regulatory research (2026-06-12)

Research for the long-short strategy track (user request 2026-06-12): how margin
is actually computed for short and long-short equity portfolios, per the
regulatory floor (Reg T + FINRA 4210) and the two target brokers (Schwab,
IBKR). The goal is a faithful margin model for the backtest so long-short
results reflect real capital requirements + carry costs.

## 1. Regulatory floor (what every broker must at least require)

### Initial margin (Reg T, 12 CFR 220)

| Position | Initial requirement |
|---|---|
| Long stock | 50% of purchase price |
| Short stock | **150% of short market value** = 100% (the short proceeds, held as collateral) + **50% additional cash/equity** |

Practical meaning for sizing: opening a $10k short requires $5k of *new*
equity; the $10k proceeds stay locked as collateral (credit balance $15k
against a $10k short market value).

### Maintenance margin (FINRA Rule 4210(c), verbatim tiers)

| Position | Maintenance requirement |
|---|---|
| Long margin-eligible stock | 25% of current market value |
| Short stock ≥ $5/share | **greater of $5.00/share or 30%** of current market value |
| Short stock < $5/share | **greater of $2.50/share or 100%** of current market value |
| Non-margin-eligible long | 100% |
| Minimum account equity | $2,000 |

Implications for the strategy's short leg:
- The per-share dollar floors make **low-priced shorts brutally capital-hungry**
  (a $3 stock shorted requires 100%+ — capital parity with the position itself;
  a $6 stock requires $5/share ≈ 83%!). The 30% tier only binds cleanly above
  ~$16.67/share ($5.00/0.30). **A short-side universe filter should require
  price ≥ ~$17** to stay on the 30% tier — cheaper-priced shorts pay 83-100%+
  margin, wrecking capital efficiency.
- Equity of a short account = credit balance − short market value; the
  requirement is recomputed daily on marked-to-market value, so shorts that
  move AGAINST you both lose money and raise the requirement (30% of a larger
  number) — margin spiral risk concentrates exactly in the squeeze scenario.

## 2. Broker layers on top of the floor

### Schwab
- House maintenance generally ~30% on longs (vs 25% regulatory), higher on
  concentrated or volatile names; short tiers track the FINRA schedule with
  house add-ons. Schwab "may increase house maintenance requirements at any
  time" without notice (disclosure doc, CRS 22760) — a margin model should
  carry a house-buffer parameter, not hardcode the floor.
- Schwab can force-liquidate without notice to meet calls; no entitlement to
  call extensions. Borrowed-against dividend payments arrive as payments
  in lieu (PIL), taxed as ordinary income — a small drag for long-margin and a
  cost OWED on shorts (short seller pays the dividend to the lender; model
  short positions as paying the full dividend on ex-date).

### Interactive Brokers
- Offers Reg-T accounts and **Portfolio Margin** (risk-based, OCC TIMS model:
  requirement = largest theoretical loss across price/vol scenarios per
  product class). PM can cut requirements well below Reg T for hedged books —
  a long-short pairs book is exactly the case PM rewards (offsetting exposures
  margined on net risk, not gross legs). PM needs $110k+ account minimum.
- IBKR computes margin **in real time** and auto-liquidates on violation
  (no margin-call grace at all) — tighter than Schwab's "attempt to involve
  you." A backtest margin model for IBKR should enforce the requirement
  intraday-continuously, not at day close.
- House requirements on special names (corporate actions, hard-to-borrow)
  override the schedule.

## 3. Carry costs of the short leg

- **Borrow fee**: annualized rate × short market value / 365, accrued daily on
  settled positions. GC (general collateral / easy-to-borrow) large-caps ≈
  0-0.5%/yr; hard-to-borrow names can run double-digit to triple-digit
  annualized. Fee floats daily with lending-market supply/demand.
- **Short rebate**: interest earned on the short proceeds ≈ short-term rate −
  borrow fee (sign can flip negative for HTB). At IBKR, credit interest on
  short proceeds is tiered and roughly benchmark-minus-spread for large
  balances; retail at Schwab generally receives no rebate.
- **Dividends**: short pays 100% of dividends on borrowed shares (plus the
  lender's PIL treatment). For dividend-paying large-caps this is ~1.5-2%/yr
  drag on the short leg before borrow fees.
- **Buy-in risk**: HTB shorts can be force-recalled at the worst moment —
  non-modelable as a fee; treat as a tail event / avoid HTB names outright.

## 4. What the backtest margin model needs (spec sketch)

1. Account-level state: cash, long market value, short market value, credit
   balance; equity = cash + LMV − SMV.
2. Requirement function (Reg-T mode):
   `req = Σ_long max(0.25, house_long) × mv + Σ_short tier(price) × smv`
   with `tier(p) = p<5 ? max(2.50/p, 1.0) : max(5.00/p, 0.30)` (+house buffer).
3. Initial gate on entry: new short needs 50% additional equity over the
   proceeds; reject orders that would breach.
4. Daily mark: recompute on close; if equity < req → forced liquidation rule
   (sell/cover in deterministic order) — this is the mechanism that turns
   margin into PATH DEPENDENCE, the thing a naive "gross exposure cap" misses.
5. Carry accrual: daily borrow fee + dividend payments on shorts; optional
   rebate credit. Default parameters: GC fee 0.3%/yr, no rebate (retail),
   dividends at actual historical rates (we have the data).
6. Universe gate for the short side: price ≥ ~$17 (30%-tier), margin-eligible,
   exclude HTB (proxy: avoid low-float/high-short-interest names — we lack
   short-interest data; price+ADV floor is the practical stand-in).
7. (Later) PM mode: net-risk margining for hedged books — only worth modeling
   if the strategy actually runs balanced long-short.

## Sources

- [FINRA Rule 4210](https://www.finra.org/rules-guidance/rulebooks/finra-rules/4210) (maintenance tiers, verbatim)
- [Reg T, 12 CFR Part 220](https://www.ecfr.gov/current/title-12/chapter-II/subchapter-A/part-220) (initial 50%/150%)
- [Schwab margin disclosure (CRS 22760)](https://www.schwab.wallst.com/pdf/activetrader/marginriskdisclosure.pdf) + [Schwab margin rates page](https://www.schwab.com/margin/margin-rates-and-requirements) (house powers, PIL)
- [IBKR margin requirements](https://www.interactivebrokers.com/en/trading/margin-requirements.php), [IBKR stock margin](https://www.interactivebrokers.com/en/trading/margin-stocks.php), [Portfolio Margin glossary](https://www.interactivebrokers.com/campus/glossary-terms/portfolio-margin-account/), [Short selling & margin lesson](https://www.interactivebrokers.com/campus/trading-lessons/short-selling-and-margin/)
- [IBKR short sale cost](https://www.interactivebrokers.com/en/pricing/short-sale-cost.php), [IBKR borrow-fee risks](https://www.interactivebrokers.com/campus/traders-insight/securities/short-selling/the-risks-of-shorting-series-part-ii-borrow-fees/)
- [Margin formulas reference](https://thismatter.com/money/stocks/margin.htm), [FINRA NtM 98-102](https://www.finra.org/rules-guidance/notices/98-102)
