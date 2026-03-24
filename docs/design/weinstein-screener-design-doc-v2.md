# Weinstein Stage Screener — Design Document

**Version:** 0.2
**Stack:** OCaml only. EODHD API for market data.
**Principle:** Data layer and presentation layer are strictly separate. All parameters are configurable, never hardcoded.

---

## 1. Project Goal

Build a full screening pipeline that implements Stan Weinstein's technical analysis framework from *Secrets for Profiting in Bull and Bear Markets*. The system operates at three levels — macro market, sector/group, and individual stock — classifies each by stage (1–4), scores buy/sell/short candidates using Weinstein's criteria, manages positions with trailing stops, and outputs structured results that any presentation layer can consume.

---

## 2. Weinstein's Framework — Decision Reference Notes

This section serves as a **permanent reference** for coding. Each subsection maps directly to book content so that implementers don't need to re-read the source material.

### 2.1 The Four Stages

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

### 2.2 Macro Market Analysis — The "Forest" (Ch. 3, 8)

**This is the first and most important filter. Without bullish macro conditions, even great individual charts have low probability of success.**

Weinstein uses multiple long-term indicators, weighted by agreement ("Weight of the Evidence"). The key ones we can compute:

#### 2.2.1 DJI/S&P 500 Stage Analysis (Ch. 8 — "Most Important Single Indicator")

Apply the same stage analysis to the market index itself:
- Plot DJI (or S&P 500) with its 30-week MA
- Stage 3 potential top on DJI → become cautious, suspend new buying
- DJI breaks below 30-week MA into Stage 4 → very defensive: sell poor RS stocks, tighten stops, begin looking for shorts
- Stage 1 base forming on DJI → prepare for next bull signal
- DJI breaks above flattening/rising 30-week MA → start aggressive buying

**Key historical pattern (Ch. 8):** "No bear market in the past several decades has unfolded without this gauge flashing a negative signal." Works equally well at bottoms.

**1987 crash example:** DJI made new high in late August (A), sold off sharply (B), rallied in October (C) but failed to reach August peak. A-B-C sequence = toppy. Meanwhile 30-week MA losing upside momentum, leveling out = Stage 3. Break below MA near 2,450 = Stage 4 sell signal. Days later: worst one-day crash in history.

#### 2.2.2 NYSE Advance-Decline Line (Ch. 8)

Cumulative daily figure: (advancing issues) − (declining issues), added to running total.

**Bearish divergence (top signal):** A-D line peaks and starts trending lower WHILE DJI continues making new highs. The longer the divergence, the more significant the eventual reversal. Historically, the A-D line peaks 5-10 months before the DJI. This showed up in: 1961 (7-month lead), 1965 (9-month lead), 1972 (10-month lead), 1987 (5-month lead, peaked March while DJI went to 2,746 in August).

**Bullish divergence (bottom signal):** DJI hits bottom and refuses to make new lows, while A-D line continues lower. This means some sectors are starting to improve even as others continue falling. Seen in: 1932-33, 1957, 1962, 1970, 1984.

**Implementation note:** Can be approximated using weekly data too. Daily A-D data may be available from EODHD or computable from individual stock data.

#### 2.2.3 Momentum Index (Ch. 8)

200-day moving average of NYSE advance-decline daily net figures.

**Rules:**
1. Most important signal: crossing the zero line in either direction. Up through zero = bullish; down through zero = bearish.
2. Longer time in positive/negative territory → more meaningful when it crosses.
3. Deepest readings before crossing → most significant signals.
4. In bull market, MI peaks before DJI — sharp drop from peak reading is early warning even while still positive.

**Sell signals:** Jan 1962, early 1969, early 1972, spring 1981, Jan 1984, Oct 1987.
**Buy signals:** Feb 1961, spring 1963, Apr 1967, Jan 1971, early 1975, Aug 1982, Jan 1985.

#### 2.2.4 New Highs minus New Lows (Ch. 8)

Weekly (preferred): new 52-week highs minus new 52-week lows on NYSE.

**Rules:**
1. Consistently positive = favorable long-term; consistently negative = unhealthy.
2. **Divergence is key:** If DJI making new highs but this gauge trending lower → negative divergence → bearish foreshadowing.
3. If DJI making new lows but this gauge trending higher → positive divergence → bullish foreshadowing.

#### 2.2.5 Global Market Confirmation (Ch. 8)

The most profitable US market moves occur when the overwhelming majority of world markets agree. Apply stage analysis to foreign indices (London, Japan, France, Germany, Australia, etc.). If foreign markets are breaking down from Stage 3 tops while US is still rallying → bearish warning. If foreign markets turning up from Stage 1 bases → bullish confirmation.

#### 2.2.6 Presidential Cycle (Ch. 3)

Four-year cycle with remarkable historical regularity:
- Year 1 (post-election): usually bad. Bear markets in 1969, 1973, 1977, 1981.
- Year 2: bear continues until mid-year bottom (e.g. Aug 1982). Second half bullish.
- Year 3: best year of cycle.
- Year 4 (election year): choppy, weakness first half, strength second half.

**Use as tilt/aggressiveness dial, not a hard signal.**

#### 2.2.7 Seasonal Patterns (Ch. 3)

- **Best months:** Nov, Dec, Jan (year-end rally is real). July/Aug also positive.
- **Worst months:** Feb, May, Jun, Sep.
- **Best day of week:** Friday. **Worst:** Monday ("Blue Monday" — especially in bear markets).
- **Pre-holiday:** Usually bullish (~68% of the time).

**Use for fine-tuning entry/exit timing, not for primary signals.**

### 2.3 Sector / Group Analysis — The "Trees" (Ch. 3)

**Second filter. Two equally bullish individual charts will perform very differently depending on sector health. Favorable chart in bullish group → 50-75% advance. Same chart in bearish group → 5-10% gain.**

#### 2.3.1 Sector Stage Analysis

Apply same stage analysis to industry group charts (S&P sector indices):
- Check what stage the group is in using 30-week MA
- Investors: concentrate buying in groups breaking out of Stage 1 bases
- Traders: lean toward continuation moves in existing Stage 2 uptrends
- **Never buy a stock from a Stage 3 or Stage 4 group, no matter how good the individual chart**
- **Never short a stock from a Stage 2 group, no matter how weak the individual chart**

**Exception:** If group is in Stage 2 but individual stock breaks below support → sell it (just don't short it).

#### 2.3.2 Sector Relative Strength

Each group has an RS line vs the market. Bullish if:
- RS line trending higher
- RS line in positive territory (above zero line)
- RS moving from negative to positive territory on breakout

#### 2.3.3 Cross-Confirmation

When scanning individual stock charts, if several stocks from one group are simultaneously turning bullish (or bearish) → strong sector signal. The group with the most excellent individual charts is likely the A+ sector.

**Real examples from book:** Casino stocks in 1978 (every single chart bullish → 105-560% gains). Mobile homes in 1982 (all 8 stocks bullish → avg 260% gain). Oil in 1986 (crude at $10, bearish headlines, but charts screamed buy → all winners).

#### 2.3.4 What Makes a Strong vs Weak Group Signal

| Factor | Bullish | Bearish |
|--------|---------|---------|
| Group MA | Rising / breaking out of Stage 1 | Declining / breaking down from Stage 3 |
| Group RS | Positive, trending higher | Negative, trending lower |
| Individual charts | Many bullish patterns | Many bearish patterns |
| Volume | Expanding on group rally | Expanding on group decline |

### 2.4 Individual Stock Buy Criteria (Ch. 3, 4, 5)

Only after macro and sector pass do we evaluate individual stocks.

#### 2.4.1 Basic Entry Requirements

1. Stock breaks out above resistance AND above 30-week MA
2. 30-week MA is no longer declining (flat or rising)
3. Breakout must NOT occur below a declining MA — **this is a trap, not a buy** (Ch. 3: Western Union example — broke out of trading range below declining MA, crashed from 45 to 8½)

#### 2.4.2 Volume Confirmation (Ch. 4)

**"Never trust a breakout that isn't accompanied by a significant increase in volume."**

- Breakout-week volume ≥ 2× average volume of prior 4 weeks, OR
- Volume build-up over 3-4 weeks that is ≥ 2× average of prior several weeks, with at least some increase on breakout week
- On pullback: volume should contract by 75%+ from peak levels → bullish confirmation for second entry

**Real examples:** Puerto Rican Cement — 10× volume on breakout → +300%. Texas Industries (same group) — volume contracted on breakout → crashed to 22. Allied Signal — volume didn't reach 2× → stalled at resistance. Goodyear — nearly triple volume → pulled back on low volume → another buy signal → doubled.

#### 2.4.3 Overhead Resistance (Ch. 4)

**Grading system:**
- **A+ (Virgin territory):** Stock has never traded above this price, or hasn't in 10+ years. No sellers wanting to "get even." Most explosive potential. (Example: Allegis 1987 — new 10-year high, rocketed 30 points)
- **A (Clean):** No significant resistance on 2.5-year chart. Minor old resistance only.
- **B (Moderate):** Some resistance overhead but not dense.
- **C (Heavy):** Dense trading zone just above breakout. Stock will use up buying power getting through this zone. (Example: Pan Am 1987 — resistance at 6½, 7, 8 → mediocre performance vs Allegis)

**Key concept:** "Support, once broken, later becomes resistance." Prior trading ranges above the breakout are ceilings the stock must push through.

**Long-range perspective:** Check 10-year price history. If breakout is a new 10-year high → strongest signal.

**Older resistance is less potent.** Over time, more investors take losses, reducing the supply at old price levels.

#### 2.4.4 Relative Strength (Ch. 4)

Formula: `RS = price_of_stock / price_of_market_average` (computed weekly, same day each week, preferably Friday).

**Rules:**
- Positive RS trend + positive other criteria → buy
- Negative RS in negative territory → NEVER buy, no matter how good other factors
- RS crossing from negative to positive territory while all other criteria met → A+ bonus signal
- Strong RS on a stock that breaks DOWN → don't short it (but still sell if you own it)
- Weak RS on a stock that breaks UP → be suspicious, likely mediocre performer

**Mansfield zero line:** RS divided by its own long-term average. Above 1.0 = positive territory, below = negative.

#### 2.4.5 Big Winner Detection — Triple Confirmation (Ch. 5)

A stock gets A+ rating if ALL THREE present:

1. **Volume explosion:** Breakout volume ≥ 2× recent average (preferably 3×+), AND volume remains heavy in following weeks
2. **RS breakout:** RS line moves from near the zero line into positive territory on the breakout
3. **Pre-breakout advance ≥ 40%:** Stock already advanced significantly during Stage 1 base before breaking out — shows accumulation by smart money

**Book examples:** Anthony Industries (volume 3×, RS crossed zero, pre-breakout advance >40% → +300%). National Semiconductor 1973 (tripled during base, RS went positive, volume 3× → +150% in 3 months, during a bear market). Blocker Energy (volume 5×, RS went positive, +200% pre-breakout → +600%).

"When you find one of these special big-winner patterns, invest much more heavily in it because the probabilities are great that you have a grand-slam home run on your hands."

### 2.5 Stop-Loss and Selling Rules (Ch. 6)

#### 2.5.1 Initial Stop Placement

- Place below the significant support floor (prior correction low) BEFORE the breakout
- **Round number rule:** If stop lands near a round number (e.g. 18⅛), place it just BELOW the round number (17⅞). Buy orders accumulate at round numbers creating support — if that level is violated, real trouble.
- Same applies at half-points (18⅝ → place at 18⅜)
- Enter stop immediately as GTC (good-til-canceled) when you buy
- **Pre-calculate stop before buying.** If stop requires >15% risk from entry → prefer other candidates.

#### 2.5.2 Trailing Stop — Investor Method

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
  AFTER each correction + recovery:
    WHEN stock rallies back near prior peak:
      new_stop = below(min(correction_low, MA))
      -- always below round numbers
    KEY: give stock plenty of room while MA is rising sharply
    KEY: don't raise stop until stock rallies well off the low

STATE: STAGE3_TIGHTENING
  TRIGGER: MA flattens out, stock oscillating around MA
  CHANGE: pull stop tighter — below correction_low even if ABOVE MA
  Rationale: higher risk zone, protect profits aggressively

STATE: EXITED
  stop is hit → sell, no questions asked
  IF whipsaw (stock later breaks out again): acceptable to re-buy
    — treat the lost points as insurance premium
```

#### 2.5.3 Trailing Stop — Trader Method

More aggressive than investor:
- Don't wait for MA violation — exit when pattern deviates from plan
- Use 4-6% initial stop if no nearby prior peak (place above round number)
- Lower stop after each rally peak that fails and stock drops to new low
- Never stay with a short that moves above its 30-week MA, even momentarily
- Use downsloping trendlines as additional stop guide (when ≥3 touches form)

#### 2.5.4 Don'ts for Selling (Ch. 6)

1. **Don't base selling on tax considerations.** (Resorts International story: held from 20→65, wouldn't sell for taxes, rode it back to 20.)
2. **Don't base selling on dividend yield.** If stock enters Stage 4, the price decline wipes out years of dividends.
3. **Don't hold hoping it will "come back."** The market doesn't know or care what you paid.

#### 2.5.5 Swing Rule — Target Projection (Ch. 6, 7)

For estimating upside/downside targets:
```
BUY target:  low_in_base (A) → peak forms → drops to new low (B)
             → rally exceeds peak → target = peak + (peak - A)

SHORT target: high_in_top (B) → drops to low (A)
              → if stock breaks below A:
              → target = A - (B - A)
```

"Usually quite accurate" — use to know when to take partial profits.

### 2.6 Short-Selling Criteria (Ch. 7)

**Mirror image of buying, with key differences:**

#### 2.6.1 Short Entry Checklist

1. **Market** trend is bearish (DJI in Stage 4, majority of long-term indicators negative)
2. **Group** is negative (below 30-week MA, RS trending lower, several individual charts weak)
3. **Individual stock** had substantial prior advance, now in Stage 3 with flat/declining MA
4. Stock breaks below support AND below 30-week MA → Stage 4 entry
5. **RS is negative and deteriorating** — NEVER short a stock with strong RS, even if it breaks down
6. Minimal nearby support below breakdown point (steep prior advance with small congestion = ideal)

#### 2.6.2 Key Differences from Buying

- **Volume NOT required for valid breakdown.** "Stocks can truly fall of their own weight." Volume increase is more bearish, but absence doesn't invalidate. (Jonathan Logan 1973: ultra-low volume on breakdown → crashed 90%)
- **Pullbacks less frequent.** Only ~50% of breakdowns pull back to the breakdown level (vs. >50% on breakouts). Traders should short full position on breakdown. Investors can do half on breakdown, half on pullback.
- **Head-and-shoulder tops:** Most bearish formation. After sharp Stage 2 advance, left shoulder → head → right shoulder with declining volume on right shoulder. "The bigger the top, the bigger the drop." Wide swing from neckline to peak = more vulnerable.

#### 2.6.3 Short Stop (Buy-Stop) Rules

- Initial buy-stop: above prior rally peak (above round number)
- Trail down as stock declines, lowering after each rally peak that fails
- When MA levels out (Stage 1 base forming): place stop above resistance even if below MA
- Use downsloping trendlines for partial profit-taking

### 2.7 Order Execution Notes (Ch. 3, 7)

- **Buy entries:** Use GTC buy-stop orders. `Buy 1,000 XYZ at 25⅛ stop – 25⅜ limit – GTC` (limit ¼ point above stop for active stocks)
- **Short entries:** Use wider limit due to uptick rule. `Sell short 1,000 XYZ at 29⅞ stop – 29⅜ limit – GTC` (limit ½ point below stop)
- **Weekend homework:** Scan chart book each weekend (~1 hour). Make list of potential buys. Enter GTC orders. Everything automatic, non-emotional.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  EODHD API (REST/JSON)                    │
│  Weekly OHLCV · Index data · Sector metadata · Bulk      │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP (cohttp-lwt-unix + yojson)
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Data Layer (OCaml)                      │
│  API client · Rate limiter · Local cache (JSON on disk)  │
│  Configurable: exchange, universe, date ranges            │
└────────────────────────┬────────────────────────────────┘
                         │ Domain types
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Core Analysis Engine (OCaml)                 │
│                                                           │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────┐ │
│  │ MA Engine     │  │ Stage         │  │ Breakout     │ │
│  │ (30w, 10w,    │  │ Classifier    │  │ Detector     │ │
│  │  weighted)    │  │ (state mach.) │  │              │ │
│  └───────┬───────┘  └───────┬───────┘  └──────┬───────┘ │
│          │                  │                  │          │
│  ┌───────┴───────┐  ┌──────┴────────┐  ┌─────┴────────┐│
│  │ Volume        │  │ Relative      │  │ Resistance   ││
│  │ Analyzer      │  │ Strength      │  │ Mapper       ││
│  └───────┬───────┘  └──────┬────────┘  └─────┬────────┘│
│          │                 │                  │          │
│  ┌───────┴─────────────────┴──────────────────┴───────┐ │
│  │              Macro Market Analyzer                   │ │
│  │  DJI/SPX stage · A-D line · Momentum Index          │ │
│  │  New highs/lows · Global markets · Cycle position   │ │
│  └─────────────────────────┬───────────────────────────┘ │
│                            │                              │
│  ┌─────────────────────────┴───────────────────────────┐ │
│  │              Sector Analyzer                         │ │
│  │  Group stage · Group RS · Cross-confirmation         │ │
│  └─────────────────────────┬───────────────────────────┘ │
│                            │                              │
│  ┌─────────────────────────┴───────────────────────────┐ │
│  │         Composite Scorer (Forest → Trees)            │ │
│  │  Macro filter → Sector filter → Stock scoring        │ │
│  │  Produces: buy candidates, short candidates, grades  │ │
│  └─────────────────────────┬───────────────────────────┘ │
│                            │                              │
│  ┌─────────────────────────┴───────────────────────────┐ │
│  │         Position Manager                             │ │
│  │  Trailing stops (investor/trader modes)              │ │
│  │  Stage transition alerts · Stop hit alerts           │ │
│  │  Swing rule targets                                  │ │
│  └─────────────────────────┬───────────────────────────┘ │
└────────────────────────────┼─────────────────────────────┘
                             │ Structured output (JSON)
                             ▼
┌─────────────────────────────────────────────────────────┐
│              Output / Presentation Layer                  │
│  Any consumer: CLI · Web UI · CSV · Alert system · etc.  │
└─────────────────────────────────────────────────────────┘
```

### 3.1 Why Pure OCaml

- EODHD's REST API is simple: `GET /api/eod/{SYMBOL}.US?period=w&fmt=json&api_token=...`
- `cohttp-lwt-unix` + `yojson` + `ppx_deriving_yojson` is a mature, well-documented stack
- Every component — from HTTP client to stage classifier to stop engine — benefits from OCaml's type system
- Pattern matching on stages and signals catches missing cases at compile time
- No cross-language boundary means simpler build, simpler debugging, simpler deployment

---

## 4. How It Will Be Used

### 4.1 Operating Cadence

Weinstein's framework is inherently **weekly**. The system should support:

| Mode | Cadence | What Happens |
|------|---------|-------------|
| **Weekly scan** | Every weekend (Fri close or Sat morning) | Full universe scan: fetch latest weekly bars, classify all stages, detect breakouts/breakdowns, score candidates, update positions/stops, generate report |
| **Daily monitor** | Each market day (after close) | Lightweight: check if any trailing stops were hit, check for intraday breakdowns on held positions, update A-D line / momentum index. NOT a full rescan. |
| **Manual / ad-hoc** | On demand | Query a specific ticker, run what-if analysis, check sector status |

**Automated or manual?** Both. The system should be runnable as:
1. A CLI tool you invoke manually (`weinstein scan`, `weinstein monitor`, `weinstein report`)
2. A cron-scheduled job that runs after market close (weekly full scan, daily monitor)

### 4.2 Position Monitoring

The **Position Manager** is a first-class component, not an afterthought:

- Maintains a `positions.json` file with all open positions (long and short)
- Each position tracks: ticker, entry price, entry date, current stop level, stop type, current stage, unrealized P&L
- On each daily monitor run: checks if any stops were hit by the day's price action
- On each weekly scan: re-evaluates stage, adjusts trailing stops per the rules in §2.5, generates alerts
- **Alerts** are emitted as structured output (JSON) that any notification system can consume (email, Slack webhook, SMS via external tool, etc.)

### 4.3 Alert Types

| Alert | Trigger | Priority |
|-------|---------|----------|
| `stop_hit` | Price crossed a trailing stop | CRITICAL — action required |
| `stage_change` | Held position changed stage (e.g. Stage 2 → 3) | HIGH |
| `new_breakout` | New A or A+ candidate detected | MEDIUM |
| `macro_shift` | Market-level stage change or indicator divergence | HIGH |
| `sector_shift` | Sector stage change for a held position's group | MEDIUM |

### 4.4 Output Format

All output is structured JSON. The presentation layer is a separate concern. Possible consumers (not built in v1 unless requested):
- `weinstein report` — CLI formatter that prints tables/summaries to terminal
- Web dashboard (React or plain HTML) — reads JSON, renders charts
- CSV export — for spreadsheet users
- Alert dispatcher — reads alerts JSON, sends to notification channels

### 4.5 Typical Weekly Workflow

```
Friday evening / Saturday morning:

1. $ weinstein fetch --exchange US          # pull latest weekly data from EODHD
2. $ weinstein scan --date 2026-03-13       # full analysis
3. Review output/2026-03-13/report.json:
   - Market status: bullish / bearish / neutral
   - Sector heatmap: which groups are in which stages
   - New buy candidates (graded A+ through C)
   - New short candidates (graded)
   - Position updates: stop adjustments, stage changes
   - Alerts: stops hit, stage transitions
4. Place GTC orders based on candidates
5. $ weinstein positions                    # review current portfolio

Weekday evenings:

1. $ weinstein monitor --date 2026-03-17    # lightweight check
2. Review: any stops hit today? any alerts?
```

---

## 5. OCaml Type Design (Core Domain)

### 5.1 Configuration — All Parameters Are Configurable

```ocaml
(** All tunable parameters live here. Nothing is hardcoded.
    Future ML-based tuning can optimize these. *)
type config = {
  (* Moving average *)
  ma_long_period      : int;    (** default: 30 weeks *)
  ma_short_period     : int;    (** default: 10 weeks (for traders) *)
  ma_weighted         : bool;   (** default: true (Mansfield-style) *)

  (* Stage classification *)
  ma_slope_threshold  : float;  (** % change over N weeks to be "flat" vs rising/declining *)
  ma_slope_lookback   : int;    (** weeks to look back for slope calc, default: 4 *)
  stage_confirm_weeks : int;    (** weeks price must be consistently above/below MA *)

  (* Breakout detection *)
  volume_min_ratio    : float;  (** minimum breakout volume / avg volume, default: 2.0 *)
  volume_avg_lookback : int;    (** weeks of volume to average, default: 4 *)
  pullback_threshold  : float;  (** % decline that counts as "substantial correction", default: 0.08 *)

  (* Resistance mapping *)
  resistance_lookback_weeks : int;   (** how far back to scan, default: 130 (2.5 years) *)
  resistance_longrange_weeks : int;  (** long-range perspective, default: 520 (10 years) *)

  (* Relative strength *)
  rs_market_index     : string; (** ticker for market benchmark, default: "GSPC.INDX" *)
  rs_zero_lookback    : int;    (** weeks for RS zero-line SMA, default: 52 *)

  (* Stop-loss *)
  max_initial_risk    : float;  (** max acceptable initial stop distance, default: 0.15 *)
  round_number_nudge  : float;  (** amount to nudge below round numbers, default: 0.125 *)

  (* Scoring weights — all configurable for future tuning *)
  score_weights       : score_weights;

  (* Universe *)
  exchanges           : string list;  (** default: ["US"] — expandable *)
  min_avg_volume      : int;          (** minimum avg weekly volume to consider *)
  min_price           : float;        (** minimum price to consider *)

  (* Macro indicators *)
  momentum_index_period : int;  (** default: 200 days *)
  ad_line_enabled       : bool;
  global_markets        : string list;  (** index tickers for global confirmation *)
}

type score_weights = {
  w_stage2_entry       : int;   (** default: 3 *)
  w_breakout_above_ma  : int;   (** default: 2 *)
  w_volume_strong      : int;   (** default: 2 *)
  w_volume_adequate    : int;   (** default: 1 *)
  w_rs_positive_rising : int;   (** default: 2 *)
  w_rs_crossing_zero   : int;   (** default: 1 *)
  w_virgin_territory   : int;   (** default: 2 *)
  w_minimal_resistance : int;   (** default: 1 *)
  w_sector_stage2      : int;   (** default: 2 *)
  w_sector_transitioning : int; (** default: 1 *)
  w_pre_breakout_advance : int; (** default: 1 *)
  w_tight_stop         : int;   (** default: 1 *)
  w_loose_stop_penalty : int;   (** default: -1 *)

  grade_thresholds     : int * int * int * int;  (** A+, A, B, C cutoffs *)
}
```

### 5.2 Core Domain Types

```ocaml
(* === Market Data === *)

type bar = {
  date      : string;     (* ISO 8601 date *)
  open_     : float;
  high      : float;
  low       : float;
  close     : float;
  adj_close : float;
  volume    : int;
}

type ticker_meta = {
  symbol   : string;      (* e.g. "AAPL.US" *)
  name     : string;
  sector   : string;
  industry : string;
  exchange : string;
}

(* === Moving Averages === *)

type ma_slope = Rising | Flat | Declining

type ma_state = {
  value : float;
  slope : ma_slope;
  slope_pct : float;      (* actual % change for continuous comparison *)
}

(* === Stage Analysis === *)

type stage =
  | Stage1 of { ma : ma_state; weeks_in_base : int }
  | Stage2 of { ma : ma_state; weeks_advancing : int; late : bool }
  | Stage3 of { ma : ma_state; weeks_topping : int }
  | Stage4 of { ma : ma_state; weeks_declining : int }

(* === Breakout / Breakdown === *)

type overhead_quality =
  | Virgin_territory
  | Clean
  | Moderate_resistance
  | Heavy_resistance

type volume_confirmation =
  | Strong  of float
  | Adequate of float
  | Weak of float

type breakout_signal = {
  ticker           : string;
  breakout_price   : float;
  resistance_level : float;
  volume_ratio     : float;
  volume_quality   : volume_confirmation;
  overhead         : overhead_quality;
  rs_trend         : rs_trend;
  stage_from       : stage;
  stage_to         : stage;
  pre_breakout_advance_pct : float option;  (* for big-winner detection *)
}

(* === Relative Strength === *)

type rs_trend =
  | Bullish_crossover     (* crossing zero line upward *)
  | Positive_rising
  | Positive_flat
  | Negative_improving
  | Negative_declining
  | Bearish_crossover     (* crossing zero line downward *)

type relative_strength = {
  current_value : float;
  zero_line     : float;
  is_positive   : bool;
  trend         : rs_trend;
}

(* === Macro Market State === *)

type market_trend = Bullish | Bearish | Neutral

type macro_state = {
  index_stage      : stage;
  index_trend      : market_trend;
  ad_divergence    : [`None | `Bullish_divergence | `Bearish_divergence];
  momentum_index   : float;
  mi_signal        : [`Above_zero | `Below_zero | `Crossing_up | `Crossing_down];
  new_hi_lo_diff   : int;
  nh_nl_divergence : [`None | `Bullish_divergence | `Bearish_divergence];
  global_consensus : [`Mostly_bullish | `Mixed | `Mostly_bearish];
  cycle_position   : [`Year1 | `Year2_first_half | `Year2_second_half | `Year3 | `Year4];
  overall          : market_trend;      (* composite assessment *)
  rationale        : string list;
}

(* === Sector State === *)

type sector_state = {
  sector_name : string;
  stage       : stage;
  rs          : relative_strength;
  bullish_count : int;   (* individual stocks in Stage 1→2 or Stage 2 *)
  bearish_count : int;   (* individual stocks in Stage 3→4 or Stage 4 *)
  rating      : [`Strong | `Neutral | `Weak];
}

(* === Scoring === *)

type grade = A_plus | A | B | C | D | F

type scored_candidate = {
  ticker            : string;
  stage             : stage;
  grade             : grade;
  score             : int;
  breakout          : breakout_signal option;
  relative_strength : relative_strength;
  sector            : sector_state;
  macro             : market_trend;
  initial_stop      : float;
  risk_pct          : float;
  swing_target      : float option;
  is_big_winner     : bool;   (* triple confirmation *)
  rationale         : string list;
}

(* === Position Management === *)

type stop_state =
  | Initial_stop
  | Trailing_below_ma
  | Trailing_below_correction_low
  | Stage3_tightened

type position_side = Long | Short

type position = {
  ticker        : string;
  side          : position_side;
  entry_price   : float;
  entry_date    : string;
  current_stop  : float;
  stop_state    : stop_state;
  stage         : stage;
  swing_target  : float option;
  unrealized_pct : float;
}

(* === Alerts === *)

type alert_priority = Critical | High | Medium | Low

type alert =
  | Stop_hit of { position : position; hit_price : float }
  | Stage_change of { ticker : string; from_ : stage; to_ : stage }
  | New_candidate of { candidate : scored_candidate }
  | Macro_shift of { from_ : market_trend; to_ : market_trend; detail : string }
  | Sector_shift of { sector : string; from_ : stage; to_ : stage }

(* === Top-Level Output === *)

type scan_result = {
  timestamp         : string;
  macro             : macro_state;
  sectors           : sector_state list;
  buy_candidates    : scored_candidate list;
  short_candidates  : scored_candidate list;
  positions         : position list;
  alerts            : alert list;
}
```

---

## 6. Key Algorithms

### 6.1 Stage Classification (State Machine)

```
INPUT: weekly bars (52+ weeks), 30-week MA series, prior stage (if known)

1. Compute 30-week MA (simple or weighted, per config.ma_weighted)
     Weighted: more recent weeks get higher weight (Mansfield style)
     Simple: equal weight to all 30 weeks

2. Determine MA slope:
     slope_pct = (MA_now - MA_{N_weeks_ago}) / MA_{N_weeks_ago}
     Rising:   slope_pct > +config.ma_slope_threshold
     Declining: slope_pct < -config.ma_slope_threshold
     Flat:     within threshold

3. Determine price position over recent config.stage_confirm_weeks:
     count_above = weeks where close > MA
     count_below = weeks where close < MA
     Consistently above: count_above / total > some threshold
     Consistently below: count_below / total > some threshold
     Oscillating: neither consistently above nor below

4. Classify:
     IF MA declining AND price consistently below → Stage 4
     IF MA rising AND price consistently above → Stage 2
     IF MA flat AND price oscillating:
       IF prior_stage ∈ {Stage4, Stage1} → Stage 1
       IF prior_stage ∈ {Stage2, Stage3} → Stage 3
       IF no prior_stage → use long-term trend direction to disambiguate
     EDGE: MA transitioning (was declining, now flat) → early Stage 1
     EDGE: MA transitioning (was rising, now flat) → early Stage 3

5. Detect late Stage 2:
     IF Stage 2 AND stock far above MA AND MA angle of ascent slowing
     → set late = true (still Stage 2 but warning flag)
```

### 6.2 Macro Market Analyzer

```
INPUT: DJI/SPX weekly bars, NYSE daily A-D data, global index bars

1. Apply stage classification to DJI/SPX
2. Compute A-D line, check for divergence vs DJI
3. Compute 200-day momentum index, check zero-line crossing
4. Compute weekly new-highs minus new-lows, check for divergence
5. Apply stage classification to global indices, assess consensus
6. Determine presidential cycle position from current date
7. Combine signals:
     IF index Stage 4 AND MI below zero AND A-D bearish divergence → Bearish
     IF index Stage 2 AND MI above zero AND no bearish divergence → Bullish
     OTHERWISE → Neutral (proceed with caution)
```

### 6.3 Sector Analyzer

```
INPUT: industry group price series (S&P sector indices or computed from constituents)

For each sector:
1. Apply stage classification to group index
2. Compute group RS vs market
3. Count individual stocks by stage within the group
4. Rate: Strong (Stage 1→2 or Stage 2, positive RS, many bullish charts)
         Weak (Stage 3→4 or Stage 4, negative RS, many bearish charts)
         Neutral (mixed)
```

### 6.4 Breakout Detection

```
INPUT: weekly bars, resistance levels, volume history

1. Identify resistance: highest high within current trading range
2. Detect breakout: close > resistance AND close > 30-week MA
3. Confirm MA: MA slope is flat or rising (NOT declining)
4. Confirm volume: breakout-week volume / avg(volume, prior N weeks)
5. Grade overhead resistance (scan 2.5yr + 10yr history)
6. Check for big-winner triple: volume, RS crossover, pre-breakout advance
```

### 6.5 Scoring Engine

```
INPUT: stage, breakout_signal, RS, sector_state, macro_state

Additive score using config.score_weights:

  Stage 2 entry from Stage 1 base       +w_stage2_entry
  Breakout above MA, MA rising           +w_breakout_above_ma
  Volume ≥ 3× avg                        +w_volume_strong
  Volume ≥ 2× avg (but < 3×)            +w_volume_adequate
  RS positive and rising                 +w_rs_positive_rising
  RS crossing zero upward                +w_rs_crossing_zero
  No overhead resistance (virgin)        +w_virgin_territory
  Minimal overhead resistance            +w_minimal_resistance
  Sector in Stage 2                      +w_sector_stage2
  Sector transitioning 1→2              +w_sector_transitioning
  Pre-breakout advance ≥ 40%            +w_pre_breakout_advance
  Initial stop ≤ 10% below entry         +w_tight_stop
  Initial stop > 15% below entry         +w_loose_stop_penalty

  Map score → grade via config thresholds
```

### 6.6 Trailing Stop Engine

See §2.5.2 for detailed state machine. Implementation tracks:
- Current stop level
- Stop state (Initial / Trailing / Tightened)
- History of correction lows and rally peaks
- Current MA value and slope
- Whether stock is in "late Stage 2" or "Stage 3 territory"

---

## 7. Data Flow

### 7.1 EODHD API Endpoints

| Endpoint | Purpose | Frequency |
|----------|---------|-----------|
| `GET /api/eod/{SYM}.US?period=w&fmt=json` | Weekly OHLCV per ticker | Weekly |
| `GET /api/eod/GSPC.INDX?period=w&fmt=json` | S&P 500 weekly (for RS + macro) | Weekly |
| `GET /api/eod/DJI.INDX?period=w&fmt=json` | Dow Jones (macro stage analysis) | Weekly |
| `GET /api/fundamentals/{SYM}.US` | Sector/industry metadata | On new tickers |
| `GET /api/exchange-symbol-list/US` | Full ticker universe | Monthly |
| Bulk API (if plan supports) | All tickers in one call | Weekly |
| Daily A-D data | For momentum index + A-D line | Daily (monitor mode) |
| Global indices | London, Japan, Germany, France, etc. | Weekly |

### 7.2 Local Cache Structure

```
data/
├── config.json                 # All parameters
├── universe/
│   └── US.json                 # Ticker list + metadata
├── weekly/
│   └── 2026-03-13/
│       ├── bars/               # {TICKER}.json per stock
│       ├── index/              # GSPC.json, DJI.json, global indices
│       └── sectors/            # Group-level aggregates
├── daily/                      # For monitor mode
│   └── 2026-03-17/
│       └── ad_data.json        # Advance-decline figures
└── positions.json              # Persistent position state
```

---

## 8. Project Structure

```
weinstein/
├── lib/
│   ├── config.ml               # Configuration types + loading
│   ├── types.ml                # Domain types (stages, signals, etc.)
│   ├── eodhd.ml                # EODHD API client (cohttp + yojson)
│   ├── cache.ml                # Local file cache read/write
│   ├── ma.ml                   # Moving average computation (simple + weighted)
│   ├── stage.ml                # Stage classifier (state machine)
│   ├── breakout.ml             # Breakout/breakdown detection
│   ├── volume.ml               # Volume analysis
│   ├── relative_strength.ml    # RS calculation and trending
│   ├── resistance.ml           # Overhead resistance mapping
│   ├── macro.ml                # Market-level analysis (DJI stage, A-D, MI, NH-NL)
│   ├── sector.ml               # Group/sector analysis
│   ├── scorer.ml               # Composite scoring engine
│   ├── stops.ml                # Trailing stop state machine
│   ├── positions.ml            # Position tracking + persistence
│   ├── alerts.ml               # Alert generation
│   ├── swing.ml                # Swing rule target projection
│   └── io.ml                   # JSON serialization (yojson + ppx)
│
├── bin/
│   ├── fetch.ml                # Data fetching entry point
│   ├── scan.ml                 # Weekly full scan
│   ├── monitor.ml              # Daily lightweight check
│   ├── report.ml               # Human-readable report formatter
│   ├── query.ml                # Ad-hoc ticker/sector query
│   └── positions_cmd.ml        # Position management CLI
│
├── output/                     # Scan results (JSON)
│   └── 2026-03-13/
│       ├── scan.json           # Full result
│       ├── macro.json          # Market state
│       ├── sectors.json        # Sector heatmap
│       ├── buy_candidates.json
│       ├── short_candidates.json
│       ├── positions.json
│       └── alerts.json
│
├── data/                       # Cache (gitignored)
├── dune-project
├── weinstein.opam
└── README.md
```

---

## 9. Build & Dependencies

```
ocaml >= 5.0
dune >= 3.0
yojson                    # JSON parsing
ppx_deriving_yojson       # auto-derive JSON serializers
cohttp-lwt-unix           # HTTP client
lwt                       # async runtime
tls                       # HTTPS support for cohttp
uri                       # URL construction
fmt                       # pretty-printing (for CLI report)
cmdliner                  # CLI argument parsing
```

---

## 10. Future Components (Documented, Not Built in v1)

### 10.1 Backtester (`backtest.ml`)

Run the full pipeline historically to evaluate performance:
- Replay weekly bars from date X to date Y
- Simulate: scan → enter positions → manage stops → exit
- Track: win rate, avg gain, avg loss, max drawdown, Sharpe-like ratio
- Compare: different parameter configurations
- Output: trade log, equity curve, performance summary

**Purpose:** Validate that the coded rules match Weinstein's described outcomes. Identify parameter sensitivity.

### 10.2 ML Parameter Tuner (`tuner.ml`)

Automated optimization of `config.score_weights` and other parameters:
- Uses backtester as the objective function
- Bayesian optimization or grid search over parameter space
- Constraints: parameters must stay within "Weinstein-reasonable" bounds
- Output: optimized config.json + performance comparison vs default

**Why document now:** Every parameter is already parameterized in `config.ml`. The tuner simply searches this space. The architecture supports it from day one.

### 10.3 Web Dashboard

React (or plain HTML + JS) frontend that reads output JSON:
- Market status dashboard with stage indicators
- Sector heatmap (stage color-coded)
- Candidate list with sortable columns
- Individual stock chart with MA overlay, volume, RS, stage annotation
- Position tracker with stop levels visualized

---

## 11. Design Decisions Log

| # | Decision | Rationale | Reference |
|---|----------|-----------|-----------|
| 1 | Pure OCaml, no Python | EODHD API is simple REST/JSON; cohttp+yojson handles it. Eliminates cross-language complexity. User preference. | §3.1 |
| 2 | Weighted MA as default | Mansfield charts (which Weinstein uses extensively) use weighted 30-week MA. More recent weeks should count more. Configurable to switch to simple. | Ch. 1, p.544-546 |
| 3 | All parameters in config, never hardcoded | Enables future ML tuning, backtesting across parameter space, and user customization without code changes. | §5.1, §10.2 |
| 4 | Stage as variant type with payload | Carry MA state + duration inside each stage. Compiler enforces exhaustive handling. Can't accidentally compare Stage1 to Stage3. | §5.2 |
| 5 | Macro analysis is first-class, not optional | Weinstein is emphatic: "without bullish macro conditions, even great individual charts have low probability of success." The macro filter gates everything. | Ch. 3 ("Forest to Trees"), Ch. 8 |
| 6 | Sector analysis is mandatory filter | "Two equally bullish charts will perform far differently depending on sector health." The system refuses to recommend buys in weak sectors. | Ch. 3, §2.3 |
| 7 | Position manager built into v1 | Weinstein's stop system is mechanical and rule-based — perfect for automation. Without it, the screening is only half the system. | Ch. 6, §2.5 |
| 8 | Weekly cadence primary, daily monitor secondary | Weinstein explicitly uses weekly charts. Daily is only for stop monitoring, not for generating new signals. | Throughout book |
| 9 | NYSE + NASDAQ to start, configurable | Broad US coverage. Architecture supports any EODHD-supported exchange. Config extensible. | §5.1 |
| 10 | Use all available historical data for resistance | Weinstein uses 2.5-year chart + 10-year long-range perspective. EODHD has 30+ years. More data = better resistance mapping. | Ch. 4 |
| 11 | Backtest and ML tuner are future components | Document the interface now, build later. Core system is designed to support them. | §10.1, §10.2 |
| 12 | Alerts are structured output, not side effects | Keep the core engine pure. Alert dispatch (email, Slack, etc.) is a consumer of alert JSON, not part of the analysis engine. | §4.3 |

---

## 12. Suggested Build Order

| Phase | What | Deliverable | Testable? |
|-------|------|-------------|-----------|
| **P0** | Config + domain types + JSON I/O | `config.ml`, `types.ml`, `io.ml` | Types compile, JSON round-trips |
| **P1** | EODHD client + cache | `eodhd.ml`, `cache.ml` | Fetch AAPL.US weekly bars, cache to disk |
| **P2** | MA engine | `ma.ml` | Compute 30w MA for any ticker, verify against known values |
| **P3** | Stage classifier | `stage.ml` | Classify AAPL, TSLA, etc. and spot-check |
| **P4** | Breakout detector + volume analyzer | `breakout.ml`, `volume.ml` | Detect known historical breakouts |
| **P5** | Relative strength | `relative_strength.ml` | RS for individual stocks vs SPX |
| **P6** | Resistance mapper | `resistance.ml` | Grade overhead for known tickers |
| **P7** | Macro market analyzer | `macro.ml` | DJI stage, A-D line, momentum index |
| **P8** | Sector analyzer | `sector.ml` | Classify S&P sectors |
| **P9** | Scoring engine | `scorer.ml` | Score candidates, verify grades make sense |
| **P10** | Position manager + stops | `positions.ml`, `stops.ml` | Simulate trailing stop on historical data |
| **P11** | CLI tools | `fetch.ml`, `scan.ml`, `monitor.ml`, `report.ml` | End-to-end weekly scan |
| **P12** | Swing rule + alerts | `swing.ml`, `alerts.ml` | Target projections, alert generation |

Each phase is independently testable. P0–P3 alone gives you a working stage scanner for individual tickers. P0–P9 gives you the full screening pipeline. P10–P12 completes the operational system.

---

## 13. What This Is Not

- **Not a trading bot.** Outputs candidates and manages stops — you place the orders.
- **Not real-time.** Weekly primary cadence, daily monitor for stops. Matches Weinstein's framework.
- **Not a backtesting framework** (yet). Documented as future component (§10.1).
- **Not financial advice.** A tool for systematic application of a published methodology.
