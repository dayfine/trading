# Trait-Y monster screen -- pre-registration (written before any result; 2026-11-13 ~00:30 PT)

Question (user, 11-12): our analyses only look at trades we took. Is there a decision-time trait Y that finds
big winners better (incl. ones we never took), so the X-type losers could be dropped?

Population: every weekly breakout of a PIT top-3000 member (pit-v12 yearly lists, list Y in force
Y-05-31 .. Y+1-05-30), 2000-01 .. 2025-06: weekly close > highest weekly high of the prior 26 weeks; week volume
>= 2x the mean of the prior 4 weeks; close > 30-week WMA and WMA not below its value 4 weeks earlier; raw close >= $5.
One event per symbol per 26 weeks (the first). Adjusted prices, Monday weeks.

Outcomes (ex post, never used as inputs):
  monster = max weekly close in the next 52 weeks >= 2x the event close
  ride    = return from the event close to the first weekly close below the 30-week WMA (max 104 weeks) -- a
            rule-based proxy for riding Stage 2; EV is judged on ride, not on the monster rate alone.

Traits Y (decision-time, at the event week): base_weeks (weeks since the last 52-week high before this one),
depth (52-week drawdown before the event), ath_gap (close vs highest high in all prior history), age (weeks of
history), price (raw close), dollar_vol (4-week mean daily $ volume), vol26 (stdev of weekly returns, 26 w),
volx (breakout volume multiple), ret26 (26-week return before), ext (close / WMA - 1), regime (S&P above its
rising WMA), eff104 (efficiency of the prior 104 weeks).

Rules: quintiles per trait. A trait "captures monsters better" only if a quintile's monster rate is >= 1.5x the
base rate in BOTH halves (2000-2012 discovery, 2013-2025 holdout) AND that quintile's mean ride beats the
population mean in both halves. 12 traits x 5 quintiles = 60 cells; expect ~3 false hits at 5 % per half, far
fewer requiring both halves. Then compare where the strategy's own entries sit on any surviving trait.

## Amendment 1 (after the first run, before reading trait results for EV): data errors
Five events carry corrupt forward series (VPI 2005 +84,478 %, NDN 2011 +53,819 %, TRA 2010 +30,268 %, LDG 2008
+10,780 %, LAF 2006 +7,339 % ride), which swamp the 2000-2012 means (population mean ride +19.8 % vs +3.8 % for
2013-2025). The EV statistic becomes the mean ride with each event capped at the population's 99.5th percentile
(+190 %); the monster rate and the PASS rule are otherwise unchanged.
