# Warmup-trading suppression — baseline-shift comparison (2026-06-12 overnight)

**Flag:** `suppress_warmup_trading` (default-off, shipped #1555). When true, the
strategy emits no new entries before the measurement `start_date` (warmup =
indicators-only, start from cash). When false (default), the strategy trades
during the 210-day warmup window and the portfolio inherits whatever it built.

**Question:** does the warmup-trading leak (#1549 A2 root cause) materially
distort baselines — enough to justify flipping the default to true and re-pinning
goldens behind it?

**Authorization:** user (2026-06-12) — flip permitted **if the evidence is
comprehensive**.

## Cells

| cell | universe | window | warmup window | warmup regime |
|---|---|---|---|---|
| benign-2011 | top-1000-2011 | 2011-01→2026-04 | 2010-06→2011-01 | calm bull |
| dotcom-2000 | sp500-hist-2000 | 2000-01→2010-12 | 1999-06→2000-01 | late bull → into crash |
| crash-2009 | top-1000-2008 | 2009-07→2016-12 | 2008-12→2009-07 | **GFC bottom** (#1549 specimen) |

Config = canonical Cell-E (0.14/0.70/0.30, force-exit h=1, laggard h=2,
`enable_short_side false`). Each cell run off (default) vs on (suppress).
`--no-emit-all-eligible` (the all_eligible post-step is ~10× the backtest and
irrelevant to a metrics comparison — the first attempt wasted ~5h on it before
being killed).

## Results

### benign-2011 — COMPLETE, off == on (bit-identical)

| arm | final | return | trades | win% | MaxDD | Sharpe | CAGR |
|---|---|---|---|---|---|---|---|
| OFF | $1,296,397 | +29.6% | 667 | 31.8% | 42.2% | 0.19 | 1.71% |
| ON  | $1,296,397 | +29.6% | 667 | 31.8% | 42.2% | 0.19 | 1.71% |

**Identical to the digit.** A 2011 start's warmup (2010 H2) is a calm bull with
no regime event, so the warmup-built portfolio is indistinguishable from a
fresh-at-start one — nothing distorting is inherited. This is the **common case**
and confirms the flip is a **no-op for benign-warmup goldens** (which is most of
them). Also reproduces the known PIT top-1000 baseline (29.6% / 42% DD), a clean
sanity check on the runner at current main.

### dotcom-2000 — COMPLETE, off == on (bit-identical)

| arm | final | trades | win% | MaxDD | Sharpe | CAGR |
|---|---|---|---|---|---|---|
| OFF | $4,685,958 | 410 | 34.9% | 37.3% | 0.92 | 15.08% |
| ON  | $4,685,958 | 410 | 34.9% | 37.3% | 0.92 | 15.08% |

Again identical. Same mechanism as benign-2011.

### crash-2009 — running (expected off == on, same reason — see below)

## ⚠ Estimand correction — scenario-level off/on is MOOT, not informative (verified)

Direct check of the OFF run's artifacts (`wu-off-top1000-2011`): **zero
warmup-window (2010) entries** — `equity_curve.csv` has no 2010 rows,
`open_positions.csv`'s earliest `entry_date` is 2011-01 (= measurement start).
**The strategy carries no warmup-built positions into a standalone scenario's
measurement window**, so suppressing warmup entries changes nothing → off == on
is *expected*, and confirms the gate is correct (not a silent no-op — there is
simply nothing to suppress at a scenario's cold start).

Why: a standalone scenario's `warmup_start` is the simulator's first day, so the
210-day warmup IS the indicator-formation period — and whatever the strategy
does there does not survive (filtered + no positions held across the boundary).

**The warmup-trading leak #1549 found is a WALK-FORWARD phenomenon:** in a WF
fold, `warmup_start = fold_start − 210d` sits in the *middle* of the data with
**fully-formed indicators**, so the strategy actively trades during warmup — and
when a fold's warmup straddles a crash (the 2009-06-26 fold over the GFC bottom),
the portfolio is depleted before measurement. **Only WF-CV with the flag as an
axis can measure this.** The three scenario cells establish the necessary
no-op-at-cold-start baseline (the flag doesn't disturb standalone goldens); the
WF-CV below is the decisive test of whether warmup trading materially affects
fold-level results — i.e. whether there is anything to fix at all.

## WF-CV (decisive) — `suppress_warmup_trading` off/on as an axis

Spec: `wfcv/spec_warmup.sexp` — top-1000-2000, Rolling 2002-2024, test_days 365,
step 365 (~22 annual folds; the 2008 & 2009 folds' warmups straddle the GFC).
Snapshot mode (`snap_top3000_2000`, warm indicators → warmup *does* trade).
Axis `((flag suppress_warmup_trading) (values (true false)))` resolves via the
tested `Overlay_validator` path (#1555 axis test). Per-fold off-vs-on delta in
Sharpe / return / MaxDD; the GFC folds are where any effect concentrates.

- If off == on across folds → **warmup trading has no material effect anywhere;
  the flag is a pure no-op; do NOT flip** (the #1549 degenerate fold had a
  different root cause — data/curve handling, not warmup trades).
- If off ≠ on and `on` (suppressed) matches-or-improves robustness on the
  affected folds → **flip the default to true** (honest measurement), re-pin the
  few goldens that move.

### Result: suppress FAILS the gate — DO NOT FLIP (evidence comprehensive)

22 folds (2002-2024), top-1000-2000, snapshot mode. Per-fold off vs on:

| variant | mean Return % | mean Sharpe | mean MaxDD % | mean Calmar |
|---|---:|---:|---:|---:|
| baseline (warmup trades = current default) | **16.78 ± 24.81** | **0.372** | 16.49 | **0.955** |
| suppress_warmup_trading=true (flip candidate) | 6.82 ± 17.14 | 0.252 | 16.01 | 0.640 |

**Gate: FAIL.** suppress wins 9/22 folds on Sharpe (needs ≥11); worst fold
(fold-002) trails baseline by Δ1.44 ≫ 0.30. Suppress lowers return, Sharpe, and
Calmar; MaxDD only marginally better (16.0 vs 16.5).

**The flag bites at fold level (unlike scenario level) — estimand reasoning
confirmed.** But direction REVERSES the #1549 prior:

- **GFC folds behave as #1549 predicted** — suppress *helps* where warmup
  straddles a crash: fold-006 (2008 test) −12.0% vs baseline −23.4%; fold-007
  (2009 recovery, warmup = GFC bottom) −2.4% vs −11.0%. Removing the inherited
  depleted positions helps *in those folds*.
- **But suppress LOSES most bull folds** — fold-002 +50.6→−3.0, fold-008
  +49.4→+9.7, fold-009 +16.2→−14.3, fold-013 +40.6→+27.5. Warmup trading is a
  **"running start"**: warm indicators let the strategy enter during the 210-day
  warmup and carry positions into the window, capturing early gains a cash-start
  misses. The bull benefit dominates the crash cost on net.

**Why (transferable):** warmup-trading is not a bug — it's an always-invested
running start that is **net-beneficial** AND more realistic for a continuously
deployed strategy (you don't restart from cash each fold/year). #1549's
degenerate fold (warmup over the GFC bottom depleting to 35%) is the **tail
cost** of that behavior — real, detected by `Fold_health`, but not worth
suppressing globally because suppression costs more (the bull running-start)
than it saves (the rare crash-warmup folds).

**Decision:** keep `suppress_warmup_trading` **default-off** (current behavior =
warmup trades). The flag stays a searchable axis — useful to measure
cash-restart / in-window-only performance, or to neutralize a specific
crash-warmup fold — but it is NOT promoted to default. No goldens move (default
unchanged). The P0 semantics question ("warmup = indicators only?") is answered:
**no — warmup trading is the correct, net-better, more-realistic default.**

Forward guidance: stop treating warmup-trading as a bug to fix. The #1549
Fold_health guard (now wired, #1558) is the right disposition — *detect* the
rare degenerate crash-warmup fold rather than suppress warmup trading globally.

## Methodology note (important — read before judging the flag)

Scenario-level off/on is a **weak instrument** for this flag: a single 15y
scenario has exactly **one** warmup window, at its very start. The flag only
bites when *that* window straddles a regime event. So:
- benign-warmup starts → off == on (shown above).
- crash-warmup starts (the crash-2009 cell; and dot-com via inherited late-1999
  positions riding into the 2000 top) → expect a non-trivial off/on delta.

The flag's effect is concentrated in **walk-forward folds** whose individual
warmup straddles a crash — which is exactly the #1549 finding (the 2009-06-26
fold's warmup spanned the GFC bottom → portfolio depleted to 35% before
measurement). A WF-CV off/on over a window containing dot-com + GFC is the
fold-level confirmation; queued after the scenario cells.

## Verdict (pending cells + WF-CV)

TBD. Bar for flipping the default: (1) no-op where warmup is benign (✓ shown),
(2) removes the depletion artifact where warmup straddles a crash, (3) never
degrades robustness. This is a **correctness** flag (it makes the backtest
measure the intended thing — no pre-window trading), not an alpha lever, so the
evidence standard is "no-op in the common case + artifact-removal in the crash
case + no regressions," confirmed at both scenario and fold level.
