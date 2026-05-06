# Capital recycling on the long side — framing note (2026-05-06)

## Problem statement

The 15y SP500 historical baseline (`goldens-sp500-historical/sp500-2010-2026.sexp`,
post-#855 / #871 settings: 510 symbols, `max_position_pct_long=0.05`,
`max_long_exposure_pct=0.50`, `min_cash_pct=0.30`) currently lands at:

- **+5.15% total return / 102 round-trips / Sharpe 0.40 / MaxDD 16.12%** over
  16 years.
- **18 long-runners** opened in Q1 2010 (AAPL, AMZN, COF, HBAN, KEY, NOVL,
  SHW, TJX, ZION, …) never stop out and lock **$1,026,058 (~100% of starting
  cash) for the entire 16-year window**.
- The cascade admits **10,945 long top-N candidates** across 822 Fridays;
  the strategy enters **120 (1.1% conversion)**.
- **681 of 751 cascade-active Fridays (90.7%) yield zero entries** — the
  cascade idles while the portfolio is full.
- The dominant rejection reason on the 120 entered Fridays is
  `Insufficient_cash` (76.2% of rivals); the silent reason on the 681
  starved Fridays is the same.

The diagnostic in `dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md`
characterizes the gap directly:

> "The strategy is starved by its own first-week saturation, and the screener
> is mostly idling… The recommendation isn't to re-tune the cascade thresholds;
> it's to make the portfolio recycle capital faster."

That note also called the symptom "the highest-leverage gap in the current
strategy implementation per the diagnostic. It dwarfs cascade-tuning,
screener-threshold-tuning, and position-sizing-tuning." The 3-cell threshold
quick-look in `dev/notes/888-score-threshold-quick-look-2026-05-06.md`
corroborates: tightening the cascade score from 40 → 41/42 dropped return by
3.8 pp on the 5y baseline because the marginal candidates dropped weren't the
losers, and the cash those losers tied up isn't being recycled productively.

The leverage point — empirically — is **how a long position exits, not how
candidates enter**. Two issues have been opened to attack that point:

- **#872** — Stage-3-detection force exits.
- **#887** — Laggard rotation / "lighten up" on lagging Stage-2 positions.

Both are unimplemented. Both originate from the same #871 finding. Before
either is implemented, the design space deserves explicit framing so the
implementations don't double-sell, leave gaps, or fail to compose with the
re-baselining that has to follow.

## Two proposed mechanisms

### Mechanism A: Stage-3 force exit (#872)

Per the issue body and `weinstein-book-reference.md` §1 and §5.2 (`STATE:
STAGE3_TIGHTENING`):

- **What it senses:** the per-position stage classifier transitions from
  Stage 2 → Stage 3. Stage 3 is "30-week MA loses upward slope, starts to
  flatten; stock tiptoes below and above the MA" (book-ref §1, Stage 3
  detail). The classifier already exists (`analysis/weinstein/screener/
  stage_classifier.ml`); the gap is that the strategy uses it for entry
  candidates, not for open-position exits.
- **What it does when fired:** market-close exit for the full position, no
  partial. Treated as a discretionary exit; semantically the same as a
  trailing-stop trigger from the position-state perspective.
- **When it fires (timing):** weekly cadence — on `on_market_close` of each
  Friday, re-classify open positions before generating new entry orders.
  Hysteresis required (issue #872 itself flags this): N=2-3 weeks of
  Stage-3 signal before exit, to avoid whipsaw on a transient flattening
  that resolves back into Stage 2.
- **Authority overlap with §5.2:** `STAGE3_TIGHTENING` already specifies
  *tightening* the trailing stop on Stage-3 detection. Mechanism A goes
  further: instead of tightening, it exits. Both are book-permitted (§5.2
  reads "tighten stop"; §5.6 reads "lighten up"; §1 Stage 3 detail reads
  "Traders: exit with profits. Investors: sell half"). Mechanism A is the
  trader-side discipline.

### Mechanism B: Laggard rotation (#887)

Per the issue body and `weinstein-book-reference.md` §5.6 (just landed in
PR #891):

- **What it senses:** RS-vs-market over a rolling N-week window combined
  with a "not-making-new-highs" condition. Issue #887 phrases this as "RS has
  been negative for N consecutive weeks (configurable; e.g., 4-6 weeks) AND
  position has not made a new high in N weeks." Operationally this is a
  candidate definition, not a fixed rule — see open question Q2 below.
- **What it does when fired:** "lighten up" — Weinstein-text wording that
  could be partial (e.g., 50%) or full. Issue #887 leaves this open;
  book-ref §5.6 says "lighten up on that position even if the sell-stop
  isn't hit. Move the proceeds into a new Stage 2 stock with greater
  promise" — partial-exit semantics if read literally.
- **When it fires (timing):** weekly. Same pre-entry pass as Mechanism A.
- **Authority distinction from A:** §5.6 fires *while still in Stage 2* —
  before the MA flattens. The trigger is "lagging badly," not topping. The
  position can be in a healthy uptrend yet still get rotated out if a
  better candidate exists and current RS is negative.

## How they interact

The two mechanisms operate on **disjoint regions** of the position lifecycle
in their canonical readings, but the boundary is fuzzy:

| Position state | A (Stage-3) | B (Laggard) |
|---|---|---|
| Stage 2, strong RS | no fire | no fire |
| Stage 2, weak/negative RS, no new high in N weeks | no fire | **fires** |
| Stage 2 → 3 transition (MA flattening) | **fires** (after hysteresis) | may fire if RS already weak |
| Stage 3 confirmed | **fires** | redundant with A |
| Stage 4 | trailing stop already triggered | n/a |

**Where they overlap:** the late-Stage-2 / early-Stage-3 boundary. A position
whose RS turns negative typically *precedes* the MA flattening — that's
exactly the §5.6 design intent ("lighten up… *even if the sell-stop isn't
hit*"). So Mechanism B fires earlier, Mechanism A confirms later. If both
sit in the strategy, B should typically fire first on the same position.

**Risk of double-sell:** if the laggard rotation fires a partial exit
(e.g., 50%), and three weeks later the same position transitions to Stage 3,
A would then exit the remaining 50%. That is *complementary*, not double-
counted — each fire reduces a different exposure slice. But if both
mechanisms are full-exit, a position rotated out under B cannot be re-fired
under A (it's no longer held). So the interaction depends entirely on
whether B is partial or full (open question Q3).

**Risk of cancellation:** B's "redeploy into a stronger candidate" only
helps if the cascade actually has a stronger candidate that week. The
diagnostic shows the cascade *does* (~13 admitted candidates per Friday on
average, on starved Fridays the same ~13 sit unfilled). So B's redeploy
condition is satisfied by construction — there is no shortage of fresh
Stage-2 candidates; the only constraint is freed cash.

**Net read:** A and B are complementary, not redundant, but the implementation
must define a **priority order when both fire on the same position the same
week** (open question Q3 below).

## Open design questions

The following questions block clean implementation. None has a single right
answer in the book or current notes.

**Q1 (Mechanism A — Stage-3 detection signature):**
What constitutes "Stage 2 → Stage 3" for a held position? Options:
- (a) MA slope flat for K weeks (e.g., 30-week MA week-over-week change <
  ε% for K=3 weeks).
- (b) Price oscillation: count of weeks where weekly close crossed the MA
  in either direction over the last K weeks ≥ threshold.
- (c) Volume-on-down-weeks > volume-on-up-weeks for K weeks.
- (d) Composite of all three (book-ref §1 Stage 3 detail uses all three).
The classifier in `analysis/weinstein/screener/stage_classifier.ml` already
has *some* answer — the open question is whether it's the right shape for
"detect Stage 3 on an open position" (which has a different prior than
"classify a candidate's stage from scratch"). Hysteresis K is also open.

**Q2 (Mechanism B — laggard threshold):**
What's "lagging badly"?
- RS measure: ratio-vs-SPY, percentile rank vs universe, or moving-average
  of either.
- Window: 4 weeks (responsive, noisy), 8 weeks (quieter, slower), 13
  weeks (one quarter, slower again).
- Comparison universe: vs SPY (simple), vs sector peers (book-ref §3
  preferred, but more state), vs the cascade's current admitted set
  (newest-strongest comparison).
- Combination with no-new-high: "no new high in N weeks" is one
  expression; alternatives include "drawdown from peak > X%" or "MA
  proximity (price within Y% of 30-week MA)."

**Q3 (A vs B priority on same position same week):**
If a position both qualifies as a laggard AND has transitioned to Stage 3:
- (a) B fires first (partial exit), A waits 1 week, fires on the
  remainder if Stage 3 still holds.
- (b) A short-circuits B (full exit, no partial pass).
- (c) B fires for full exit, A is moot.
- (d) Both fire — same week — A wins (full exit) since it's the stronger
  signal.
The choice affects post-merge fixture behaviour: (b) and (c) yield fewer
exit_reason variety in `trades.csv`; (a) yields a recognizable partial-
followed-by-full pattern.

**Q4 (Stop-state interaction):**
Today, an exit zeroes the trailing-stop state — the position is gone, the
stop is irrelevant. After Mechanism A or B exits, if the same symbol
**re-screens** as a fresh Stage-2 candidate later in the run, does it
re-enter from scratch (fresh INITIAL stop)? Or is there a cooldown?
- Cooldown 0 = no special handling. Same-Friday or near-week re-entry is
  possible. Risk of churn.
- Cooldown N weeks = once exited under A or B, the symbol is suppressed
  from cascade re-admission for N weeks.
The book gives no direct guidance on cooldown; §5.2 STATE:EXITED notes
"IF whipsaw (stock later breaks out again): acceptable to re-buy" which
suggests **no cooldown is the book-aligned default**.

**Q5 (Re-entry after partial exit under B):**
If B does a 50% lighten-up and the position later resumes a strong Stage 2
advance, does the original position remain at 50%? Or does the strategy
re-buy back to the original target size? Two regimes:
- Static: 50% remains 50% until trailing stop or another A/B fire.
- Restorative: the cascade can re-admit this symbol and round-trip back
  up to target.
Restorative requires the cascade to know "this symbol was lightened, it's
OK to re-add." Today the cascade rejects already-held symbols
(`Already_held` is a skip reason). Restorative regime requires either
exception logic or a "partially held" flag in the held-set check.

**Q6 (Backtest acceptance metric):**
What signature constitutes a clean win?
- (a) Total return improves materially (e.g., +5% → +15% on 15y) at
  unchanged or lower MaxDD.
- (b) Trade count rises into the 200-400 acceptance band from #856 with
  Sharpe ≥ 0.6 (the gate that no `max_position_pct_long` cell could pass).
- (c) "Capital efficiency": average dollars-deployed-per-day over the run.
  Today, ~$1M is deployed nominally but ~$1M is locked in 18 dead-or-flat
  positions; capital-efficiency = (cumulative new-trade cash deployed) /
  (avg available cash × days). This metric specifically rewards
  recycling, in a way (a) and (b) only proxy for.

(c) is the most direct correlate of the mechanism's intent. (a) and (b)
are user-facing and commitment-friendly; (c) is the implementation signal.
A combined gate is probably "(a) AND (c) move in the same direction, (b)
is monitored not gated" — see § Acceptance gates below.

## Recommended sequencing

1. **Run #870 (fixed-dollar all-eligible) on sp500-15y first to bound the
   alpha left on the table.** This is the upper-bound diagnostic. It
   allocates a fixed $X (e.g., $10K) per Stage-2 entry signal across the
   full 16-year window with zero portfolio rejections. Output: per-trade
   alpha distribution + grade. If the upper-bound alpha on the
   ~10,945 cascade-admitted candidates is, say, +200% return aggregate,
   then we know A+B together can — at maximum — close from +5.15% toward
   that ceiling minus the position-sizing/rejection cost. If the
   upper-bound alpha is negative or marginal, the framing is wrong and
   capital recycling buys nothing real. Either result is decisive. The
   tool is unimplemented (open issue) but designed (~400-700 LOC; bypasses
   `portfolio_risk` + `stops_runner`).

2. **Implement A (#872) before B (#887).** Reasons:
   - **Stage-3 detection is more deterministic than laggard scoring.**
     The signal (MA flat for K weeks) is geometric and config-driven;
     "lagging badly" requires a comparison universe and an RS-window
     choice (open question Q2). A gives a falsifiable per-trade signal
     a reviewer can reproduce; B requires baseline-pinning of the RS
     comparison surface.
   - **A has direct authority text** (§5.2 STAGE3_TIGHTENING, §1 Stage 3
     detail). B's authority text (§5.6) just landed (PR #891) and is
     prose-only with no operational definition.
   - **A's fixture-pinning effort is bounded.** It re-baselines all goldens-
     sp500-historical scenarios with one new exit_reason. B's RS-window
     choice expands the search space.

3. **Re-baseline the 15y after A. Then evaluate the marginal contribution
   of B.** Quantitative pivot:
   - If A alone closes most of the gap (say, returns rise from +5% to
     +25-40%, capital efficiency normalizes), B becomes a polish move,
     not a unblocker. Implement B with low priority and no acceptance gate.
   - If A closes only a fraction (returns rise to +10-15%), B remains
     a distinct lever. Implement with the open-question answers from
     Q2-Q5 anchored against the post-A baseline.
   - If A closes nothing meaningful (returns unchanged or worse), the
     mechanism is wrong-diagnosed — back to #870's upper-bound result
     for re-framing. Possible cause: the long-runners aren't transitioning
     to Stage 3 ever (genuine multi-year Stage 2 advances); B's "lagging
     in Stage 2" is the only viable signal.

4. **After A is pinned, run a `min_score_override` sweep** (the deferred
   sweep in `dev/notes/888-score-threshold-quick-look-2026-05-06.md`).
   Tighter scoring should compound with capital recycling once A unbinds
   the trade-count ceiling — that hypothesis can finally be tested.

## Acceptance gates (proposed, not committed)

For Mechanism A (#872):

- **A must improve total_return_pct on sp500-2010-2026 by ≥ 5 pp** over
  the +5.15% baseline (i.e., ≥ +10.15%) AND not regress MaxDD beyond
  -2 pp (i.e., new MaxDD ≤ 18.12%).
- **A must produce ≥ 5 Stage-3 exit events** in the 15y window. Issue
  #872's success criterion ("> 0 Stage-3 exits") is too weak; a rule
  with 1-2 fires across 16 years is statistically indistinguishable
  from fixture noise.
- **A must not regress sp500-2019-2023 by more than -3 pp on
  total_return.** Re-pinning is required; a fail here means the
  hysteresis is wrong (probably K too low — exits firing on
  Stage-2-late wobbles).
- **Capital-efficiency proxy** (e.g., `entered_count / starved_friday_count`
  or `avg_cash_deployed_pct`) must move materially positive.

For Mechanism B (#887, conditional on A's outcome):

- **Same return-and-MaxDD gates as A**, evaluated on the
  *post-A* baseline (not the pre-A +5.15% baseline).
- **B must produce ≥ 5 laggard-rotation events.** Same rationale.
- **B must not regress trade win-rate by more than -3 pp.** A naive RS-
  laggard rule can rotate out of positions that are merely consolidating
  before resuming; the win-rate gate is the canary.

**Counter-pattern from #856 to avoid:**

The #856 grid sweep imposed an acceptance gate of *"≥ 50% return AND 200-
400 trades AND Sharpe ≥ 0.6"* — and **no cell in the grid could pass it**.
The gate was structurally infeasible against the surface being swept
(`max_position_pct_long`), because the underlying mechanism (capital
recycling) isn't in the surface. Acceptance gates for A and B must be
calibrated against what the mechanism can actually move, not against the
absolute target. The #870 upper-bound run determines what's actually
movable; calibrate gates to a reasonable fraction of that, not to an
externally-imposed target like #856's.

## Out of scope

The following adjacent threads are deliberately not addressed here:

- **Short-side capital recycling (#859 et al.)** — the short-side trace
  in #871 shows zero entries (`enable_short_side=false`); recycling on
  the short side is a separate problem with separate G1-G4 gaps in
  `feat-weinstein`.
- **Continuation buys (#889 / book-ref §4.6)** — adds new entry
  triggers on already-trending stocks. Different problem class
  (entry surface, not exit surface).
- **Tuning weights (M5.5 T-A grid_search)** — the cascade
  scoring-weight sweep was deferred per #871's "highest-leverage gap"
  ranking; it remains downstream of A landing.
- **Initial-cash sweep / synthetic-portfolio runs** — recommendation 4
  in the optimal-strategy diagnostic (raise to $5M starting cash) is a
  fixture-only change with no behaviour delta; it tests whether the
  mechanism is real or just a $1M-toy artefact, but it doesn't change
  the implementation calculus.
- **`min_cash_pct` / `max_long_exposure_pct` re-tuning** — the #855
  override pattern remains the right surface for those, downstream
  of A.

## References

### Issues

- [#872](https://github.com/dayfine/trading/issues/872) — Stage-3 force
  exits proposal.
- [#887](https://github.com/dayfine/trading/issues/887) — Laggard rotation
  / lighten-up proposal.
- [#870](https://github.com/dayfine/trading/issues/870) — Fixed-dollar
  all-eligible diagnostic (upper-bound alpha measurement).
- [#871](https://github.com/dayfine/trading/issues/871) — 15y zero-trades
  diagnosis (root finding).
- [#856](https://github.com/dayfine/trading/issues/856) — `max_position_
  pct_long` grid sweep (structural infeasibility evidence).
- [#888](https://github.com/dayfine/trading/issues/888) — Score-threshold
  parameter (path-dependency caveat).

### Notes & PRs

- `dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md` — the
  primary empirical evidence (capital-recycling = highest-leverage gap).
- `dev/notes/15y-sp500-zero-trades-diagnosis-2026-05-03.md` — earlier
  root-cause walk for the 15y window.
- `dev/notes/856-grid-sweep-2026-05-05.md` — `max_position_pct_long`
  cell-by-cell evidence.
- `dev/notes/888-score-threshold-quick-look-2026-05-06.md` — score-
  threshold sweep showing path-dependency without recycling.
- PR #855 — 15y fixture override (1.0% → 5.15% return; 102 trades).
- PR #891 — book-ref §4.6 continuation buys + §5.6 laggard rotation
  added to `weinstein-book-reference.md`.

### Authority docs

- `docs/design/weinstein-book-reference.md` §1 (Stage definitions),
  §5.1-5.6 (stops, sells, laggard rotation).
- `docs/design/eng-design-3-portfolio-stops.md` (stop state machine
  contract).

### Code surfaces likely to change

- `analysis/weinstein/strategy/weinstein_strategy.ml`
  (`_on_market_close` integration point for both A and B).
- `analysis/weinstein/screener/stage_classifier.ml` (Stage-3
  classifier — already exists; reuse for A).
- `trading/trading/backtest/lib/runner.ml` /
  `trading/trading/backtest/lib/result_writer.ml` (new exit_reason
  variants for `trades.csv`).
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/
  sp500-2010-2026.sexp` and `sp500-2019-2023.sexp` (re-pinning post-
  merge).
