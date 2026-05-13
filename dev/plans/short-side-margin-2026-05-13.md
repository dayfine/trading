# Short-side margin modeling + 2-stage validation — design plan

**Issue:** [#859](https://github.com/dayfine/trading/issues/859) — short-side
strategy: margin account modeling + 2-stage validation (short-only →
long-short).

**Filed:** 2026-05-13.

**Status:** Design only. No code. Plan unblocks 5+ future implementation
sessions by sequencing the work into reviewable PRs with explicit
go/no-go acceptance gates between phases.

---

## 0. TL;DR

Today's simulator credits short proceeds as ordinary cash (Stance A from
`dev/notes/short-cash-accounting-design-2026-05-01.md`). On the 16y
`sp500-2010-2026-longshort` baseline (PR #1066), shorts add no
risk-adjusted return: Sharpe 0.70 (long-short) vs 0.71 (long-only),
MaxDD 19.8% vs 19.9%. M5.4 E1 smoke runs are worse (0 wins, 5 losses
plus 1 open-position drag).

Hypothesis: realistic friction makes shorts strictly negative-EV at the
strategy's current Stage-4 entry edge. Plan:

1. **Phase 1–2 (margin + borrow fee)** — implement Reg-T-style margin
   plus daily borrow fee under a default-off `enable_margin_accounting`
   flag. Long-only goldens stay bit-equal; with-shorts goldens re-pin.
2. **Phase 3–4 (Stage A short-only validation)** — re-run the
   short-only strategy against 3 bear-grind windows with margin on.
   Acceptance gate: Sharpe > 0 on ≥2 of 3. If fails → close issue
   with `enable_short_side = false`.
3. **Phase 5 (Stage B long-short combined)** — gated on Phase 4. Re-run
   5y + 16y golden long-short scenarios with margin on, compare to
   long-only twins.

Estimated total work: 5 PRs, ~1100 LOC code + 3 reports. The single
biggest risk is **universe coverage for the 2000-2002 + 2008 windows**
(see §5).

---

## 1. Margin accounting model

### 1.1 Three concepts to model

| Concept | Today | Target |
|---|---|---|
| **Initial collateral** | `current_cash += entry_price * qty` (full credit) | Lock `150% * notional` of cash; only the entry-price worth of cash is "credited" back from proceeds — the extra 50% comes from existing cash |
| **Maintenance margin** | None | When `(entry_price * qty + initial_cash_locked - current_price * qty) / (current_price * qty) < ~0.25`, fire a buy-to-cover (margin call) |
| **Borrow fee** | Zero | Daily debit of `short_notional * fee_rate / 252` against cash |

Concrete arithmetic for one short of 100 shares at $50 (notional $5000):

```
                           Today                  Phase 1 (margin on)
current_cash before        $10,000                $10,000
short proceeds             +$5,000  (free cash)   +$5,000  (held)
margin requirement         (none)                 -$2,500  (extra 50%
                                                  locked alongside)
current_cash after entry   $15,000                $10,000 - $2,500
                                                  = $7,500 free, $7,500
                                                  locked (= 150%
                                                  notional)
position_sizing denom      portfolio_value        sizing_cash =
                                                  current_cash - locked
```

`sizing_cash` is the new denominator for
`Portfolio_risk.compute_position_size`. The rest of the existing
position-sizing math (risk-pct × portfolio_value / |entry - stop|)
stays unchanged, but with `sizing_cash` substituting for
`portfolio_value` as the effective cash cap on long sizing.

This subsumes the design recommendation in
`dev/notes/short-cash-accounting-design-2026-05-01.md` §"Recommended
design (Stance B)" — the prior note is what this plan implements.

### 1.2 The exact seams (file inventory)

**Primary cash-arithmetic site:**

- `trading/trading/portfolio/lib/portfolio.ml`:255-258
  `_calculate_cash_change`:
  - Buy: `-(qty*price + commission)`
  - Sell: `+(qty*price - commission)` — the latter applies symmetrically
    to closing-long-sell and opening-short-sell today, which is the bug.

- `trading/trading/portfolio/lib/portfolio.ml`:328-340
  `_check_sufficient_cash` — already does a soft floor; the new model
  replaces it with a hard `available_cash` check that excludes locked
  collateral.

**Type extensions:**

- `trading/trading/portfolio/lib/portfolio.mli`:7-15 — `t` gains
  `locked_collateral : float` (or sibling `margin_state : Margin_state.t`)
  alongside `current_cash`.
- `trading/trading/portfolio/lib/types.mli` — possibly a `margin_state`
  record (collateral_locked, borrow_fee_accrued, last_fee_date) if the
  bookkeeping is non-trivial.

**Force-cover routing:**

- New margin-call exit reuses the `Force_liquidation` audit path under a
  new `margin_call` trigger variant. Existing trigger surface in
  `trading/trading/weinstein/audit/lib/force_liquidation_*.ml`.

**Position sizing:**

- `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml`
  `compute_position_size` gains `~sizing_cash` arg.
- Caller: `trading/trading/weinstein/strategy/lib/entry_audit_capture.ml`
  (and any other consumer found via grep).

**Simulator wiring:**

- `trading/trading/simulation/lib/simulator.ml` — broker-fill paths read
  + write `current_cash` in two places (trade application + force-liq
  cash recovery). Audit both for the new lock/release semantics.

### 1.3 Core-module impact — A1 decision item

**qc-structural A1 will FLAG on Phase 1.** The Portfolio module is on
the A1 watch-list (`.claude/rules/qc-structural-authority.md`). The
change is unavoidable: cash and collateral accounting live in
`Portfolio.t`.

**Argument that A1 is generalizable (per qc-behavioral A1):** margin is
a broker-side concept, not Weinstein-specific. Any strategy that opens
short positions in this simulator should benefit from realistic margin
modeling — the change does not encode Weinstein stage logic into the
portfolio module. Concretely, the new `locked_collateral` field, the
`borrow_fee_rate` parameter, and the maintenance-margin trigger are all
broker-level abstractions that apply identically to a momentum,
mean-reversion, or pairs strategy.

The Weinstein-specific piece (margin-call → buy-to-cover routing in the
strategy state machine) stays in `trading/trading/weinstein/`; the
Portfolio change exposes a generic "force-cover" event the strategy
layer interprets.

**Recommended A1 mitigation:**

- Phase 1 PR body explicitly states the generalizability argument and
  cites this plan §1.3.
- New parameters live behind `enable_margin_accounting` (default
  `false`). When the flag is off, all behaviour is bit-equal to current
  state — long-only goldens stay pinned without re-pinning.
- The new types are designed to support future variants (Portfolio
  Margin haircut, hard-to-borrow per-symbol fee) without further
  Portfolio.t changes.

### 1.4 Borrow fee model

Single configurable annual rate, applied daily:

- Config field: `short_borrow_fee_annual : float [@default 0.005]`
  (50 bps annualized — a "liquid SP500" default per issue #859).
- Daily accrual: `daily_fee = sum_of_short_notional * rate / 252`,
  deducted from `current_cash` on each trading-day tick.
- Single rate (not per-symbol) for Phase 2. Per-symbol hard-to-borrow
  flag is deferred (issue #859 §"Out of scope").

The accrual site is most naturally `Simulator.run_day_step` (or
wherever the daily tick already touches portfolio mark-to-market), not
inside `Portfolio.apply_trades` — the latter is trade-event-driven, not
time-driven.

---

## 2. Sequencing — Stage A (short-only validation)

### 2.1 Bear-window scenarios

Three scenarios. Each is a new sexp in
`dev/experiments/short-only-validation-2026-XX-XX/scenarios/`:

| Window | Date range | Universe | Notes |
|---|---|---|---|
| **2008 GFC** | 2007-10-01 .. 2009-03-31 | `broad-1000-30y` (305 SP500 cohort + 695 alphabetic backfill, all with data back to ≤1996-01-01) | 17 mo. Canonical bear-grind. **Survivorship-bias warning per universe file:** every symbol is a 30y+ survivor — long-side metrics overstated. For short-only this matters less (shorts are killed by survivors, not by them), but expect some bias against shorts. |
| **2022 bear** | 2022-01-01 .. 2022-10-31 | `sp500-historical/sp500-2010-01-01.sexp` (510 symbols, pinned 2010-01-01 cohort) | 10 mo. Modern liquidity profile. The 2010 cohort is already used in the 16y goldens, so this scenario is the cheapest to wire. |
| **2000-2002 dot-com** | 2000-03-01 .. 2002-10-31 | `broad-1000-30y` again (same survivorship caveat) | 32 mo. 3-year grinding decline. **Risk:** see §5 — data coverage for 1000 symbols pre-2002 is the most-likely blocker. Plan should validate data availability before committing this scenario. |

For each: a new sexp config with
`enable_short_side = true, enable_long_side = false` (new flag — see
issue #859 acceptance criteria).

### 2.2 Metrics + acceptance gate

For each window, report:

- **Sharpe ratio** (annualized).
- **Total return** (cumulative).
- **Max drawdown** (peak-to-trough).
- **Margin-call count** (new audit category — distinct from
  stop-out / portfolio-floor exits).
- **Total trades** + **win rate**.
- **Avg holding days** + **median holding days** (shorts often run
  longer than longs because of trailing buy-stop dynamics).
- **Annualized borrow fee paid** (sanity check on §1.4 math).

**Acceptance gate (Phase 4 → Phase 5):**

- **PASS** if Sharpe > 0 on **≥2 of 3** windows (Sharpe ≤ 0 on the third
  is acceptable — sample of 3 is small).
- **FAIL** otherwise → close issue #859 with verdict
  "default `enable_short_side = false`". Ship long-only.

The Sharpe > 0 bar is deliberately low. We are testing for "is there an
edge at all", not "is the edge large". If the strategy can't even
produce a positive risk-adjusted return in 2 of 3 dedicated bear
windows, the Stage-4 short entry has no edge and adds friction to the
long-short backtest.

---

## 3. Sequencing — Stage B (long-short combined)

Gated on Stage A success.

### 3.1 Scenarios to re-pin

Both existing goldens re-pinned with margin on:

| Golden | Today's baseline (margin off) | Margin-on target |
|---|---|---|
| `goldens-sp500/sp500-2019-2023.sexp` (5y) | 32 trades / -0.01% return / 5.8% MaxDD / 0 force-liqs | Re-measured under margin model; long-side sizing should be unchanged on shared-entry trades, short-side should retreat (some shorts now infeasible due to collateral or get force-covered earlier) |
| `goldens-sp500-historical/sp500-2010-2026-longshort.sexp` (16y) | Sharpe 0.70 / Calmar 0.46 / MaxDD 19.8% (per PR #1066) | Same scenario with margin on |

### 3.2 Acceptance gate

For each scenario, compare to the **long-only twin** on the same window:

- 5y compare to `sp500-2019-2023-long-only.sexp`.
- 16y compare to `sp500-2010-2026.sexp` (long-only, 16y).

**Acceptance gate (Phase 5 → ship):**

- **PASS** if long-short Sharpe **>= long-only Sharpe** on **both**
  windows. Margin model is realistic; shorts now add value.
- **WARN** if long-short Sharpe matches but with lower MaxDD or
  higher Sortino — shorts add diversification, not direct return.
  Decision: ship long-short with documented caveats.
- **FAIL** otherwise (long-short Sharpe drops below long-only on the
  realistic-friction model). Verdict: shorts are a friction tax that
  no parameter tuning will fix. Close #859 with `enable_short_side = false`
  default flip and a `dev/reviews/short-only-validation-2026-XX-XX.md`
  documenting the death of the short-side branch.

### 3.3 Why this gate is asymmetric

Long-only Sharpe is the "do nothing extra" baseline; long-short must
clear it to justify the implementation cost + cognitive overhead of
maintaining the short-side surface. The hedging-during-Bearish-macro
argument is theoretical; the gate is empirical.

---

## 4. Implementation phases (5 PRs)

### Phase 1: margin accounting (foundation)

**PR title:** `feat(portfolio): margin accounting — collateral lock + maintenance margin (issue #859)`

**LOC estimate:** ~350-450 (split across mli, ml, tests).

**Files touched:**

- `trading/trading/portfolio/lib/portfolio.{ml,mli}` — extend `t` with
  `locked_collateral : float`; replace cash-change dispatch for Sell on
  opening-short.
- `trading/trading/portfolio/lib/types.{ml,mli}` — possibly a new
  `margin_state` record.
- `trading/trading/portfolio/test/test_portfolio.ml` — extensive new
  tests: short open + short close + margin call + cash floor.
- New: `trading/trading/portfolio/lib/margin_state.{ml,mli}` (if
  margin state warrants its own module; otherwise inline in
  portfolio.ml).
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml`
  — new `enable_margin_accounting : bool [@sexp.default false]`,
  `initial_margin_pct : float [@sexp.default 1.50]`,
  `maintenance_margin_pct : float [@sexp.default 1.25]`.

**Key tests:**

1. Long-only trade flows produce bit-equal portfolio state vs.
   pre-change (i.e., when `enable_margin_accounting = false`).
2. Short open with sufficient cash: 150% notional locked; remaining
   `available_cash` matches expected.
3. Short open with insufficient cash: Insufficient_margin error.
4. Maintenance margin breach: synthetic price move pushes per-position
   equity ratio below 0.25; portfolio fires a force-cover via the
   audit path.
5. Short cover (buy-to-cover): collateral released; realized P&L = (entry
   - cover) * qty - commission.
6. New goldens: `goldens-sp500/margin-on-margin-off-parity.sexp` —
   long-only run that asserts margin-on vs margin-off bit-equal portfolio
   state across all 200+ trades.

**Acceptance:** all existing tests pass; long-only goldens pinned and
bit-equal; 6 new test cases pass.

### Phase 2: borrow fee

**PR title:** `feat(portfolio): daily short borrow fee accrual (issue #859)`

**LOC estimate:** ~150-200.

**Files touched:**

- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml`
  — new `short_borrow_fee_annual : float [@sexp.default 0.005]`.
- `trading/trading/simulation/lib/simulator.ml` — daily-tick fee
  accrual hook. Reads `sum_of_short_notional` from portfolio, debits
  cash by `notional * rate / 252`.
- `trading/trading/portfolio/lib/portfolio.{ml,mli}` — possibly a
  helper `Portfolio.accrue_borrow_fee : t -> rate:float -> t` (pure
  function; no validation needed since fees are always positive).

**Key tests:**

1. Daily fee math: 100 shares short at $50, 252 trading days, 50bps →
   $25 accrued over 1 trading year.
2. Fee accrues only on trading days (no weekend double-counting).
3. Multiple short positions accrue independently per-position then sum.
4. Long-only portfolio: fee accrual is identically zero (no shorts).
5. Margin-off portfolio: fee accrual is identically zero (regardless
   of shorts) — the fee depends on `enable_margin_accounting = true`.

**Acceptance:** unit tests pass; rate-zero short-side golden bit-equal
to Phase 1 (sanity check).

### Phase 3: Stage A scenario fixtures

**PR title:** `feat(experiments): short-only bear-window scenario fixtures (Stage A, issue #859)`

**LOC estimate:** ~150-300 (mostly sexp configs + a README).

**Files touched:**

- New: `dev/experiments/short-only-validation-2026-XX-XX/README.md` —
  problem statement, scenario inventory, acceptance gate.
- New: `dev/experiments/short-only-validation-2026-XX-XX/scenarios/`
  with 3 sexp files (2008-gfc, 2022-bear, 2000-02-dotcom).
- Possibly new universe file: if `broad-1000-30y` lacks pre-2002
  coverage (risk per §5), build a `broad-30y-2000.sexp` snapshot via
  `build_universe.exe`. This depends on EODHD/Wiki data coverage —
  treat as conditional task.
- New `enable_long_side : bool [@sexp.default true]` flag in
  `weinstein_strategy_config.ml`. (Mirrors existing `enable_short_side`.)

**Key tests:** none beyond sexp-parse smoke. The scenarios are config
data, not code.

**Acceptance:** all 3 scenarios parse + a smoke run (1 month each)
completes without crashing.

### Phase 4: Stage A execution + go/no-go report

**PR title:** `docs(reviews): short-only validation report (Stage A, issue #859)`

**LOC estimate:** ~0 code + 1 report (~500-line markdown).

**Files touched:**

- New: `dev/reviews/short-only-validation-2026-XX-XX.md` — full report
  with metrics table per scenario, charts (text-based since no Python
  per `.claude/rules/no-python.md`), interpretation, go/no-go verdict.

**Acceptance:** report verdict (PASS/FAIL) drives whether Phase 5
proceeds.

### Phase 5 (conditional on Phase 4 PASS): Stage B re-pin + report

**PR title:** `feat(goldens): re-pin long-short scenarios with margin model on (Stage B, issue #859)`

**LOC estimate:** ~100 (golden range updates) + 1 report.

**Files touched:**

- `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
  — re-pinned expected block.
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026-longshort.sexp`
  — re-pinned expected block.
- New: `dev/reviews/long-short-margin-validation-2026-XX-XX.md` —
  comparison table vs long-only twins, verdict on whether shorts add
  value at realistic friction.
- Default flip: `enable_margin_accounting = true` becomes the new
  config default, since long-only goldens stay bit-equal in either mode.

**Acceptance:** §3.2 acceptance gate decides whether the
`enable_short_side` default also flips.

---

## 5. Risk + open questions

### 5.1 Current accounting under-penalises shorts — confirm before Phase 1

The hypothesis in #859 is "current accounting under-penalises shorts."
Read the existing cash arithmetic to confirm:

- `trading/trading/portfolio/lib/portfolio.ml`:255-258
  `_calculate_cash_change` — confirmed: opening a short via `Sell`
  branch credits `(qty * price - commission)` to cash unconditionally.
  No collateral lock; no borrow fee. Position sizing
  (`Portfolio_risk.compute_position_size` consuming
  `Portfolio_view.portfolio_value`) treats this credited cash as freely
  available for new long entries. This is Stance A in
  `short-cash-accounting-design-2026-05-01.md` §"Stance A: Cash-account
  semantics" — the empirical measurement there showed ~15-20% inflated
  long-side sizing on shared entries. Phase 1 directly fixes this seam.

### 5.2 Data coverage for Stage A windows

The 510-symbol `sp500-2010-01-01.sexp` universe covers the 2022 bear
fully but **starts in 2010** — it cannot cover the 2008 GFC or 2000-02
dot-com windows. Two options:

1. **Use `broad-1000-30y`** — 1000 symbols with data back to ≤1996,
   including 305 SP500 survivors. Already pinned + used by capacity
   tests. Survivorship-biased, but the bias hurts longs more than
   shorts (survivors are by definition stocks that didn't go to zero;
   shorting them produces fewer winners, not more). **Recommend this
   option as the default for both GFC + dotcom.**
2. **Build a fresh as-of-2007-10-01 + as-of-2000-03-01 SP500 snapshot**
   via `build_universe.exe` (same Wiki+EODHD path as the 2010 snapshot,
   per the universe file's source comment). More accurate but blocks
   Phase 3 on a data build session. **Defer unless Phase 4 result is
   ambiguous and we need to remove the survivorship-bias confound.**

Decision: start with option 1 in Phase 3, document the bias, escalate
to option 2 only if Phase 4 result is borderline.

### 5.3 M5.4-E1 evidence is under no-friction accounting

The issue notes that E1's "0 wins, 5 losses + 1 open-position drag"
result is under today's no-friction simulator. Phase 4's prediction
ahead of execution: **expect Phase 4 metrics to be worse than E1, not
better.** The realistic borrow fee + Reg-T initial margin do not make
losing shorts profitable; they just stop the simulator from flattering
them. This colors the Phase 4 PASS/FAIL prior — we should be prepared
for FAIL.

If FAIL: the constructive interpretation is that the Weinstein
short-side Stage-4 entry rule (mirror of Stage-2 long) is a
domain-correct rule that the modern liquidity regime + index-fund
flows have made unprofitable. The book is honest about shorts being
harder (Ch. 7); the modern era is harder still. Closing the issue with
`enable_short_side = false` is a legitimate outcome, not a failure of
the implementation.

### 5.4 Open design questions

1. **Sizing denominator nuance.** Pure Stance B uses
   `sizing_cash = current_cash` for position-sizing. Real brokers
   pledge ~50% of short proceeds back under Reg-T. Plan punts: Phase 1
   uses pure Stance B; revisit in a follow-up if Stage A passes and
   long-short under-allocates relative to broker reality.
2. **Maintenance ratio default.** Industry default is ~25% equity (33%
   on notional). Plan uses that. Configurable for tuning.
3. **Borrow fee per-symbol.** Single rate for Phase 2.
   Hard-to-borrow per-symbol flag in `dev/notes/short-side-gaps-2026-04-29.md`
   §"Out of scope" — leave deferred.
4. **Simultaneous long+short during macro transitions.** The issue
   raises this as a strategy design question — leave for a follow-up
   experiment; out of scope for the margin-modeling work.

---

## 6. Authority references

- `docs/design/weinstein-book-reference.md` §6 "Short-Selling Criteria
  (Ch. 7)" — the book's short-entry rules. The book treats shorts
  symmetrically with longs; margin is a broker concept the book does
  not engage with. The book's "money risked" model is implicitly
  margin-style (the trader puts up cash; shorts add risk on top of
  that cash). Phase 1's design aligns with this.
- `docs/design/eng-design-3-portfolio-stops.md` §"Portfolio risk
  management" — existing portfolio-risk surface; the new margin
  primitives extend rather than replace it.
- `dev/notes/short-cash-accounting-design-2026-05-01.md` — the prior
  design note this plan formalizes + extends. Concrete numbers on
  long-side sizing inflation (~15-20%) under today's Stance A.
- `dev/notes/short-side-gaps-2026-04-29.md` — closed G1-G9 mechanical
  bugs; the margin model assumes these are all closed.
- `dev/experiments/short-on-off/README.md` — M5.4 E1 evidence.
- PR #1066 — the 16y long-short baseline this plan re-pins in Phase 5.

---

## 7. Phase ordering rationale (executive summary)

| Phase | Why now | Why this order |
|---|---|---|
| 1. Margin accounting | Hard prerequisite for any short-side measurement to be interpretable | Default-off flag makes this risk-free for existing goldens |
| 2. Borrow fee | Cheap to add once §1 lands | Builds on §1's `enable_margin_accounting` flag |
| 3. Stage A fixtures | Data + config plumbing for §4 | Can land in parallel with §2 once §1 merges |
| 4. Stage A execution + report | The actual go/no-go test | Single biggest source of project risk; do this before §5 to avoid wasted re-pin work if shorts fail |
| 5. Stage B re-pin + report | Final validation that long-short ≥ long-only at realistic friction | Conditional on §4 passing; cheapest phase but no value if §4 fails |

The plan is deliberately structured so that Phases 1-4 can be executed
sequentially with one project-killer gate at Phase 4. Phase 5 is purely
upside.
