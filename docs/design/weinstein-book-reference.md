# Weinstein Book Reference — Decision Rules for Implementation

**Source:** Stan Weinstein, *Secrets for Profiting in Bull and Bear Markets*

This document is a **permanent reference** for coding. Each subsection maps directly to book content so that implementers don't need to re-read the source material. For the system design and engineering docs, see the other files in this directory.

---

## 1. The Four Stages

Every stock (and every index, and every sector group) is in exactly one stage at any point in time. The stage is determined by the relationship between price and the 30-week moving average (MA), the slope of the MA, and the prior stage context.

| Stage | Name | 30-Week MA Behavior | Price vs MA | Market Meaning |
|-------|------|---------------------|-------------|----------------|
| 1 | Basing | Flattening (was declining) | Oscillates around MA | Equilibrium after decline; accumulation |
| 2 | Advancing | Rising | Consistently above MA | Demand overwhelms supply; uptrend |
| 3 | Topping | Flattening (was rising) | Oscillates around MA | Equilibrium after advance; distribution |
| 4 | Declining | Falling | Consistently below MA | Supply overwhelms demand; downtrend |

**Stage 1 detail (Ch. 2):** After several months of decline, downside momentum fades. Volume usually lessens ("dries up") during base formation but may expand late in Stage 1 even as prices stay flat — this signals that dumping by disgruntled holders is being absorbed without driving price lower. On the chart: the 30-week MA loses its downside slope and starts to flatten. Intermittent rallies and declines toss the stock above and below the MA. Swings between support (bottom of trading range) and resistance (top of range). Basing can last months or years. **Rule: don't buy in Stage 1 — money gets tied up with little movement.**

**Stage 2 detail (Ch. 2):** Begins when stock breaks out above the top of the resistance zone AND above the 30-week MA on impressive volume. After initial rally, usually at least one pullback close to the breakout point — this is a second chance to buy. The less it pulls back, the more strength it shows. At breakout point, fundamentals are often still negative. In Stage 2: MA starts turning up shortly after breakout. Each successive rally peak is higher than the last. Correction lows are progressively higher. All corrections are contained above the rising 30-week MA. **Late Stage 2 warning:** when stock sags closer to its MA, angle of MA ascent slows, stock is being "discovered" — still a "hold" but no longer a buy; reward/risk has shifted against you.

**Stage 3 detail (Ch. 2):** Advance loses momentum, starts trending sideways. Volume usually heavy, moves sharp and choppy ("churning" — sideways on heavy volume). Heavy buying from those excited by fundamentals is met by aggressive selling from early buyers heading for exits. On chart: 30-week MA loses upward slope, starts to flatten. Stock tiptoes below and above the MA (whereas in Stage 2 declines always held at or above). **Traders: exit with profits. Investors: sell half, protect remaining half with tight sell-stop below support.** Never buy in this stage — reward/risk strongly stacked against.

**Stage 4 detail (Ch. 2):** Stock breaks below bottom of support zone. Unlike upside breakouts, downside breaks do NOT need huge volume increase to be valid — stocks can fall of their own weight. But volume increase on breakdown is even more bearish. Each decline drops to new low, each rally falls short of prior peak — textbook downtrend. All below declining MA. **Absolute rule: NEVER buy or hold in Stage 4. NEVER average down.**

## 2. Macro Market Analysis — The "Forest" (Ch. 3, 8)

**This is the first and most important filter. Without bullish macro conditions, even great individual charts have low probability of success.**

Weinstein uses multiple long-term indicators, weighted by agreement ("Weight of the Evidence"). The key ones we can compute:

### 2.1 DJI/S&P 500 Stage Analysis (Ch. 8 — "Most Important Single Indicator")

Apply the same stage analysis to the market index itself:
- Plot DJI (or S&P 500) with its 30-week MA
- Stage 3 potential top on DJI → become cautious, suspend new buying
- DJI breaks below 30-week MA into Stage 4 → very defensive: sell poor RS stocks, tighten stops, begin looking for shorts
- Stage 1 base forming on DJI → prepare for next bull signal
- DJI breaks above flattening/rising 30-week MA → start aggressive buying

**Key historical pattern (Ch. 8):** "No bear market in the past several decades has unfolded without this gauge flashing a negative signal." Works equally well at bottoms.

**1987 crash example:** DJI made new high in late August (A), sold off sharply (B), rallied in October (C) but failed to reach August peak. A-B-C sequence = toppy. Meanwhile 30-week MA losing upside momentum, leveling out = Stage 3. Break below MA near 2,450 = Stage 4 sell signal. Days later: worst one-day crash in history.

### 2.2 NYSE Advance-Decline Line (Ch. 8)

Cumulative daily figure: (advancing issues) − (declining issues), added to running total.

**Bearish divergence (top signal):** A-D line peaks and starts trending lower WHILE DJI continues making new highs. The longer the divergence, the more significant the eventual reversal. Historically, the A-D line peaks 5-10 months before the DJI. This showed up in: 1961 (7-month lead), 1965 (9-month lead), 1972 (10-month lead), 1987 (5-month lead, peaked March while DJI went to 2,746 in August).

**Bullish divergence (bottom signal):** DJI hits bottom and refuses to make new lows, while A-D line continues lower. This means some sectors are starting to improve even as others continue falling. Seen in: 1932-33, 1957, 1962, 1970, 1984.

**Implementation note:** Can be approximated using weekly data too. Daily A-D data may be available from EODHD or computable from individual stock data.

### 2.3 Momentum Index (Ch. 8)

200-day moving average of NYSE advance-decline daily net figures.

**Rules:**
1. Most important signal: crossing the zero line in either direction. Up through zero = bullish; down through zero = bearish.
2. Longer time in positive/negative territory → more meaningful when it crosses.
3. Deepest readings before crossing → most significant signals.
4. In bull market, MI peaks before DJI — sharp drop from peak reading is early warning even while still positive.

**Sell signals:** Jan 1962, early 1969, early 1972, spring 1981, Jan 1984, Oct 1987.
**Buy signals:** Feb 1961, spring 1963, Apr 1967, Jan 1971, early 1975, Aug 1982, Jan 1985.

### 2.4 New Highs minus New Lows (Ch. 8)

Weekly (preferred): new 52-week highs minus new 52-week lows on NYSE.

**Rules:**
1. Consistently positive = favorable long-term; consistently negative = unhealthy.
2. **Divergence is key:** If DJI making new highs but this gauge trending lower → negative divergence → bearish foreshadowing.
3. If DJI making new lows but this gauge trending higher → positive divergence → bullish foreshadowing.

### 2.5 Global Market Confirmation (Ch. 8)

The most profitable US market moves occur when the overwhelming majority of world markets agree. Apply stage analysis to foreign indices (London, Japan, France, Germany, Australia, etc.). If foreign markets are breaking down from Stage 3 tops while US is still rallying → bearish warning. If foreign markets turning up from Stage 1 bases → bullish confirmation.

### 2.6 Presidential Cycle (Ch. 3)

Four-year cycle with remarkable historical regularity:
- Year 1 (post-election): usually bad. Bear markets in 1969, 1973, 1977, 1981.
- Year 2: bear continues until mid-year bottom (e.g. Aug 1982). Second half bullish.
- Year 3: best year of cycle.
- Year 4 (election year): choppy, weakness first half, strength second half.

**Use as tilt/aggressiveness dial, not a hard signal.**

### 2.7 Seasonal Patterns (Ch. 3)

- **Best months:** Nov, Dec, Jan (year-end rally is real). July/Aug also positive.
- **Worst months:** Feb, May, Jun, Sep.
- **Best day of week:** Friday. **Worst:** Monday ("Blue Monday" — especially in bear markets).
- **Pre-holiday:** Usually bullish (~68% of the time).

**Use for fine-tuning entry/exit timing, not for primary signals.**

## 3. Sector / Group Analysis — The "Trees" (Ch. 3)

**Second filter. Two equally bullish individual charts will perform very differently depending on sector health. Favorable chart in bullish group → 50-75% advance. Same chart in bearish group → 5-10% gain.**

### 3.1 Sector Stage Analysis

Apply same stage analysis to industry group charts (S&P sector indices):
- Check what stage the group is in using 30-week MA
- Investors: concentrate buying in groups breaking out of Stage 1 bases
- Traders: lean toward continuation moves in existing Stage 2 uptrends
- **Never buy a stock from a Stage 3 or Stage 4 group, no matter how good the individual chart**
- **Never short a stock from a Stage 2 group, no matter how weak the individual chart**

**Exception:** If group is in Stage 2 but individual stock breaks below support → sell it (just don't short it).

### 3.2 Sector Relative Strength

Each group has an RS line vs the market. Bullish if:
- RS line trending higher
- RS line in positive territory (above zero line)
- RS moving from negative to positive territory on breakout

### 3.3 Cross-Confirmation

When scanning individual stock charts, if several stocks from one group are simultaneously turning bullish (or bearish) → strong sector signal. The group with the most excellent individual charts is likely the A+ sector.

**Real examples from book:** Casino stocks in 1978 (every single chart bullish → 105-560% gains). Mobile homes in 1982 (all 8 stocks bullish → avg 260% gain). Oil in 1986 (crude at $10, bearish headlines, but charts screamed buy → all winners).

### 3.4 What Makes a Strong vs Weak Group Signal

| Factor | Bullish | Bearish |
|--------|---------|---------|
| Group MA | Rising / breaking out of Stage 1 | Declining / breaking down from Stage 3 |
| Group RS | Positive, trending higher | Negative, trending lower |
| Individual charts | Many bullish patterns | Many bearish patterns |
| Volume | Expanding on group rally | Expanding on group decline |

## 4. Individual Stock Buy Criteria (Ch. 3, 4, 5)

Only after macro and sector pass do we evaluate individual stocks.

### 4.1 Basic Entry Requirements

1. Stock breaks out above resistance AND above 30-week MA
2. 30-week MA is no longer declining (flat or rising)
3. Breakout must NOT occur below a declining MA — **this is a trap, not a buy** (Ch. 3: Western Union example — broke out of trading range below declining MA, crashed from 45 to 8½)

### 4.2 Volume Confirmation (Ch. 4)

**"Never trust a breakout that isn't accompanied by a significant increase in volume."**

- Breakout-week volume ≥ 2× average volume of prior 4 weeks, OR
- Volume build-up over 3-4 weeks that is ≥ 2× average of prior several weeks, with at least some increase on breakout week
- On pullback: volume should contract by 75%+ from peak levels → bullish confirmation for second entry

**Real examples:** Puerto Rican Cement — 10× volume on breakout → +300%. Texas Industries (same group) — volume contracted on breakout → crashed to 22. Allied Signal — volume didn't reach 2× → stalled at resistance. Goodyear — nearly triple volume → pulled back on low volume → another buy signal → doubled.

### 4.3 Overhead Resistance (Ch. 4)

**Grading system:**
- **A+ (Virgin territory):** Stock has never traded above this price, or hasn't in 10+ years. No sellers wanting to "get even." Most explosive potential. (Example: Allegis 1987 — new 10-year high, rocketed 30 points)
- **A (Clean):** No significant resistance on 2.5-year chart. Minor old resistance only.
- **B (Moderate):** Some resistance overhead but not dense.
- **C (Heavy):** Dense trading zone just above breakout. Stock will use up buying power getting through this zone. (Example: Pan Am 1987 — resistance at 6½, 7, 8 → mediocre performance vs Allegis)

**Key concept:** "Support, once broken, later becomes resistance." Prior trading ranges above the breakout are ceilings the stock must push through.

**Long-range perspective:** Check 10-year price history. If breakout is a new 10-year high → strongest signal.

**Older resistance is less potent.** Over time, more investors take losses, reducing the supply at old price levels.

### 4.4 Relative Strength (Ch. 4)

Formula: `RS = price_of_stock / price_of_market_average` (computed weekly, same day each week, preferably Friday).

**Rules:**
- Positive RS trend + positive other criteria → buy
- Negative RS in negative territory → NEVER buy, no matter how good other factors
- RS crossing from negative to positive territory while all other criteria met → A+ bonus signal
- Strong RS on a stock that breaks DOWN → don't short it (but still sell if you own it)
- Weak RS on a stock that breaks UP → be suspicious, likely mediocre performer

**Mansfield zero line:** RS divided by its own long-term average. Above 1.0 = positive territory, below = negative.

### 4.5 Big Winner Detection — Triple Confirmation (Ch. 5)

A stock gets A+ rating if ALL THREE present:

1. **Volume explosion:** Breakout volume ≥ 2× recent average (preferably 3×+), AND volume remains heavy in following weeks
2. **RS breakout:** RS line moves from near the zero line into positive territory on the breakout
3. **Pre-breakout advance ≥ 40%:** Stock already advanced significantly during Stage 1 base before breaking out — shows accumulation by smart money

**Book examples:** Anthony Industries (volume 3×, RS crossed zero, pre-breakout advance >40% → +300%). National Semiconductor 1973 (tripled during base, RS went positive, volume 3× → +150% in 3 months, during a bear market). Blocker Energy (volume 5×, RS went positive, +200% pre-breakout → +600%).

"When you find one of these special big-winner patterns, invest much more heavily in it because the probabilities are great that you have a grand-slam home run on your hands."

### 4.6 Continuation Buys (Ch. 3, ~lines 2214–2238)

A second category of buy signal that occurs within an established Stage 2 uptrend — distinct from the initial breakout.

> "There is one other very profitable time to do new buying. It occurs after a Stage 2 advance is well underway, when the stock drops back close to its MA and consolidates. It then breaks out anew above the top of its resistance zone... This is called a continuation buy."

**Trader-vs-investor framing:**

> "This type of buy is more suited to traders than investors. But investors, too, should be willing to do some late Stage 2 buying when the overall market is very strong and there aren't many initial breakout opportunities left."

**MA-trending-up requirement (mandatory):**

> "The moving average should be clearly trending higher. This is important! Just as a marathon runner needs something left in reserve for the finish, so does a Stage 2 advancing stock. If the MA starts to roll over and flatten out, you don't want that stock."

**Key distinctions from initial breakout:**

- Greater risk of false breakout (stock is further along in Stage 2).
- Probabilities are "overwhelmingly high" that the advance will be rapid if conditions hold.
- Volume confirmation still required; pullback-to-MA on low volume is the setup.
- **Inapplicable in early bull markets** (plenty of initial breakouts; no need to chase continuation buys).
- **Most relevant in late bull markets** (1986–1987 example: few first-time Stage 2 buys left, continuation variety still occurring).

**Implementation note:** Continuation buys are a distinct buy_reason enum value from initial breakouts — they share the same volume + RS checks but the MA-slope check is stricter (MA must be *clearly* trending higher, not merely flat-to-rising). Source: Ch. 3, ~lines 2214–2238.

## 5. Stop-Loss and Selling Rules (Ch. 6)

### 5.1 Initial Stop Placement

- Place below the significant support floor (prior correction low) BEFORE the breakout
- **Round number rule:** If stop lands near a round number (e.g. 18⅛), place it just BELOW the round number (17⅞). Buy orders accumulate at round numbers creating support — if that level is violated, real trouble.
- Same applies at half-points (18⅝ → place at 18⅜)
- Enter stop immediately as GTC (good-til-canceled) when you buy
- **Pre-calculate stop before buying.** If stop requires >15% risk from entry → prefer other candidates.

### 5.2 Trailing Stop — Investor Method

State machine with explicit transitions:

```
STATE: INITIAL
  stop = below prior correction low / below round number
  WAIT for first substantial correction (8-10%+)

STATE: FIRST_CORRECTION
  stock corrects 8-10%+, then starts rallying back toward prior peak
  WHEN stock rallies back near prior peak:
    IF correction_low < MA:
      new_stop = below(MA)
    ELSE:
      new_stop = below(MA)  -- keep below MA even if correction held above
    TRANSITION to TRAILING

STATE: TRAILING (repeat for each correction cycle)
  AFTER each correction (8-10%+) + recovery back near prior peak:
    new_stop = below(min(correction_low, MA))
    -- "the sell-stop was always kept below the MA even if the correction
       low held above it" (Ch. 6, Merck example)
    -- "Continue moving the sell-stop up as the MA advances (points E, G, I)"
       — each successive ratchet uses the current (risen) MA, so stops
       trend upward across correction cycles
    -- always below round numbers
  BETWEEN corrections: stop stays put
    -- "give stock plenty of room while MA is rising sharply"
    -- "don't raise stop until stock rallies well off the low"

STATE: STAGE3_TIGHTENING
  TRIGGER: MA flattens out, stock oscillating around MA
  CHANGE: pull stop tighter — below correction_low even if ABOVE MA
  Rationale: higher risk zone, protect profits aggressively

STATE: EXITED
  stop is hit → sell, no questions asked
  IF whipsaw (stock later breaks out again): acceptable to re-buy
    — treat the lost points as insurance premium
```

### 5.3 Trailing Stop — Trader Method

More aggressive than investor:
- Don't wait for MA violation — exit when pattern deviates from plan
- Use 4-6% initial stop if no nearby prior peak (place above round number)
- Lower stop after each rally peak that fails and stock drops to new low
- Never stay with a short that moves above its 30-week MA, even momentarily
- Use downsloping trendlines as additional stop guide (when ≥3 touches form)

### 5.4 Don'ts for Selling (Ch. 6)

1. **Don't base selling on tax considerations.** (Resorts International story: held from 20→65, wouldn't sell for taxes, rode it back to 20.)
2. **Don't base selling on dividend yield.** If stock enters Stage 4, the price decline wipes out years of dividends.
3. **Don't hold hoping it will "come back."** The market doesn't know or care what you paid.

### 5.5 Swing Rule — Target Projection (Ch. 6, 7)

For estimating upside/downside targets:
```
BUY target:  low_in_base (A) → peak forms → drops to new low (B)
             → rally exceeds peak → target = peak + (peak - A)

SHORT target: high_in_top (B) → drops to low (A)
              → if stock breaks below A:
              → target = A - (B - A)
```

"Usually quite accurate" — use to know when to take partial profits.

### 5.6 Laggard Rotation (Ch. 4, ~lines 4929–4933)

An active position-management rule that fires *before* the trailing stop is hit — exits a lagging position mid-Stage-2 to redeploy into a stronger candidate. Complements §5.2 STAGE3_TIGHTENING, which tightens the stop once the MA flattens; laggard rotation operates earlier in the position lifecycle, while the MA is still rising.

**Surrounding context:**

> "The proper way to look at your stocks is to make believe that each position is the only one you have. If it's acting fine, great, ride with it. But if it's lagging badly and acting poorly, lighten up on that position even if the sell-stop isn't hit. Move the proceeds into a new Stage 2 stock with greater promise."

**Key rules:**

- Evaluate each position in isolation — do not let winners subsidize laggards.
- "Lagging badly and acting poorly" is the trigger, not a stop breach. Poor relative action mid-Stage-2 is sufficient.
- Proceeds move immediately into a fresh Stage 2 breakout with better RS and volume characteristics.
- Does NOT replace the trailing stop — the stop remains in place; this rule fires earlier as a discretionary exit.

**Implementation note:** Laggard rotation is a separate exit_reason from stop_hit and stage3_tightening. It is optionally configurable (some investors prefer to let stops do all the work); the default Weinstein method uses it. Source: Ch. 4 §portfolio sizing, ~lines 4929–4933.

## 6. Short-Selling Criteria (Ch. 7)

**Mirror image of buying, with key differences:**

### 6.1 Short Entry Checklist

1. **Market** trend is bearish (DJI in Stage 4, majority of long-term indicators negative)
2. **Group** is negative (below 30-week MA, RS trending lower, several individual charts weak)
3. **Individual stock** had substantial prior advance, now in Stage 3 with flat/declining MA
4. Stock breaks below support AND below 30-week MA → Stage 4 entry
5. **RS is negative and deteriorating** — NEVER short a stock with strong RS, even if it breaks down
6. Minimal nearby support below breakdown point (steep prior advance with small congestion = ideal)

### 6.2 Key Differences from Buying

- **Volume NOT required for valid breakdown.** "Stocks can truly fall of their own weight." Volume increase is more bearish, but absence doesn't invalidate. (Jonathan Logan 1973: ultra-low volume on breakdown → crashed 90%)
- **Pullbacks less frequent.** Only ~50% of breakdowns pull back to the breakdown level (vs. >50% on breakouts). Traders should short full position on breakdown. Investors can do half on breakdown, half on pullback.
- **Head-and-shoulder tops:** Most bearish formation. After sharp Stage 2 advance, left shoulder → head → right shoulder with declining volume on right shoulder. "The bigger the top, the bigger the drop." Wide swing from neckline to peak = more vulnerable.

### 6.3 Short Stop (Buy-Stop) Rules

- Initial buy-stop: above prior rally peak (above round number)
- Trail down as stock declines, lowering after each rally peak that fails
- When MA levels out (Stage 1 base forming): place stop above resistance even if below MA
- Use downsloping trendlines for partial profit-taking

## 7. Order Execution Notes (Ch. 3, 7)

- **Buy entries:** Use GTC buy-stop orders. `Buy 1,000 XYZ at 25⅛ stop – 25⅜ limit – GTC` (limit ¼ point above stop for active stocks)
- **Short entries:** Use wider limit due to uptick rule. `Sell short 1,000 XYZ at 29⅞ stop – 29⅜ limit – GTC` (limit ½ point below stop)
- **Weekend homework:** Scan chart book each weekend (~1 hour). Make list of potential buys. Enter GTC orders. Everything automatic, non-emotional.
