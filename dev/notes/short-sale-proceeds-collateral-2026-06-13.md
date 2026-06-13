# Short-sale proceeds collateral — design recommendation (NS2, #1563)

## Last updated: 2026-06-13

Read-only design analysis for the cash-floor-correctness track item NS2. **No
code in this PR** — the implementation is a separate, human-gated dispatch that
depends on the maintainer ratifying the recommendation below.

Companion docs:
- `dev/status/cash-floor-correctness.md` (NS2 brief)
- `dev/notes/long-short-margin-mechanics-2026-06-12.md` (Reg-T / FINRA margin
  research — the faithful model NS2 must eventually conform to)

---

## 1. Problem statement

### 1.1 Backtests run margin-OFF

`Margin_config.default_config` carries `enabled = false`
(`trading/trading/portfolio/lib/margin_config.ml:18` →
`default_enabled = false`). The simulator takes the default unless a caller
overrides it (`simulator.ml:30`,
`?(margin_config = Trading_portfolio.Margin_config.default_config)`). No
production backtest spec flips it on, so the live + backtest path is the
non-margin path.

### 1.2 The short-sale cash path with margin OFF

A short open is a `Sell` into a flat/short position. Cash impact is computed by
`Portfolio._calculate_cash_change` (`portfolio.ml:271-274`):

```ocaml
let _calculate_cash_change (trade : Trading_base.Types.trade) =
  match trade.side with
  | Buy  -> -.((trade.quantity *. trade.price) +. trade.commission)
  | Sell ->   (trade.quantity *. trade.price)  -. trade.commission
```

For a `Sell`, `cash_change` is **positive** — the short proceeds are added
straight to `current_cash` in `apply_single_trade` (`portfolio.ml:378-398`,
`current_cash = new_cash`). There is no offsetting entry.

The collateral machinery that *would* offset it lives in
`portfolio_margin.ml`, but it is gated off:

- `apply_single_trade_with_margin` (`portfolio_margin.ml:100-107`) short-circuits
  to the plain `Portfolio.apply_single_trade` when `not margin_config.enabled` —
  so `_apply_short_open` / `_initial_collateral_for_short`
  (`portfolio_margin.ml:37-70`), which would add to `locked_collateral`, never
  runs.
- `locked_collateral` therefore stays `0.0` for the entire backtest
  (`portfolio.ml:20-23`: "0.0 under legacy Stance-A semantics; the
  `apply_*_with_margin` APIs are the sole writers").

### 1.3 How `_check_sufficient_cash` interacts

`_check_sufficient_cash` (`portfolio.ml:347-352`) delegates to
`Portfolio_cash_floor.check`, whose floor is
`current_cash + checked_change + negative_unrealized_pnl >= 0`
(`portfolio_cash_floor.ml:60-67`). It is an **absolute-dollar solvency floor on
`current_cash`** — it does not know about collateral. Because a short *raises*
`current_cash`, the floor never resists opening a short; if anything the short
proceeds make the floor *easier* to clear for the next trade.

### 1.4 Why short sizing over-deploys (the concrete defect)

Position sizing reads the **gross** cash figure, not the
collateral-net figure:

- `Portfolio_risk.snapshot_of_portfolio` (`portfolio_risk.ml:171-173`) builds the
  sizing snapshot with `~cash:portfolio.current_cash` — i.e. `current_cash`, *not*
  `Portfolio.available_cash` (`portfolio.ml:498-499`,
  `current_cash -. locked_collateral`).
- `available_cash` is exactly the field designed to net out pledged collateral,
  and its docstring says "Strategy code should read this rather than
  `current_cash` when sizing new entries." With margin OFF it equals
  `current_cash` anyway (locked is 0), so the call site silently does the wrong
  thing only on the short leg.

Worked example (Reg-T economics from `long-short-margin-mechanics`, §1):

1. Start: `current_cash = $1,000,000`, no positions. Sizing budget = $1M.
2. Short $300k notional of stock A. Margin OFF: proceeds `+$300k` →
   `current_cash = $1,300,000`, `locked_collateral = 0`.
3. Next entry's sizing budget is now **$1.3M**, not the ~$850k a real Reg-T
   account would show (a $300k short locks the $300k proceeds **plus** $150k new
   equity as collateral → buying power *drops* by ~$150k, it does not rise by
   $300k).
4. So each short *expands* the apparent budget, and the strategy keeps sizing
   subsequent positions off an inflated number. Short notional compounds upward
   instead of being constrained.

This is consistent with the observed pathologies the sizing caps were patched to
contain — "ABBV short at 124% of $1M starting portfolio"
(`portfolio_risk.ml:191-192`) and the negative-`portfolio_value` clamp
(`portfolio_risk.ml:207-217`). Those caps are downstream band-aids on a budget
that the upstream cash figure has already inflated. The
`max_short_notional_fraction = 0.30` cap (`portfolio_risk.ml:54,75`) helps but
operates on `portfolio_value`, which is itself contaminated by the same
proceeds.

**Net:** with margin OFF, short proceeds are spendable cash with no collateral
lock, so the short leg systematically over-deploys relative to any realistic
broker account. This is invisible on the long-only Cell-E baseline (no shorts)
and only bites the long-short track.

---

## 2. The three options

### (a) Enable margin mode in backtests

**What it changes.** Flip backtest specs to `margin_config.enabled = true`. The
existing, already-implemented `portfolio_margin.ml` path then locks
`(1 + initial_margin_pct) × qty × price` collateral on every short open
(`_initial_collateral_for_short`, `margin_config.ml:32` →
`total_collateral_factor = 1.50`), releases it proportionally on cover, accrues
daily borrow fee, and runs maintenance-margin checks. To actually fix sizing,
the snapshot call (`portfolio_risk.ml:173`) must additionally switch from
`current_cash` to `Portfolio.available_cash` so the locked collateral nets out
of the sizing budget.

**Blast radius. LARGE — moves every short-side baseline.** Turning margin on
changes realized cash flows (borrow fee debits, collateral locks gate entries
that previously passed), forced-liquidation path-dependence
(`long-short-margin-mechanics` §4), and the sizing budget. Every long-short
golden / baseline re-pins. Long-only goldens are untouched *only if* the spec
keeps margin OFF for them — i.e. this becomes a per-spec setting, not a global
flip.

**Experiment-flag-discipline.** `enabled` already defaults to `false`
(R1 satisfied — it is the no-op). It is a `Margin_config` field, not yet a
`Weinstein_strategy.config` axis field, so R2 ("searchable as a
`Variant_matrix` axis") is **not** met today — wiring `margin_config.enabled`
(and the margin params) through `Overlay_validator` would be additional work.
R3 (no default-on without a ledger ACCEPT) means we cannot make this the global
default until a WF-CV experiment accepts it.

**Effort. Medium-large.** The accounting code exists, but: (1) the
`current_cash`→`available_cash` sizing fix, (2) per-spec wiring + axis exposure,
(3) the full FINRA tier model from `long-short-margin-mechanics` §4 (per-share
dollar floors, maintenance spiral, dividends) is **not** implemented — current
margin is a flat `initial_margin_pct`/`maintenance_margin_pct`, so "margin on"
today is only an approximation of the real requirement.

### (b) Reserve proceeds as locked collateral in the non-margin path, behind a default-off flag

**What it changes.** Add a narrow flag (e.g.
`lock_short_proceeds_as_collateral : bool [@sexp.default false]`) that, even with
`margin_config.enabled = false`, routes short opens/covers through the
collateral lock/release in `portfolio_margin.ml` (or a slimmed copy) so
`locked_collateral` reflects the proceeds. Fix `portfolio_risk.ml:173` to read
`available_cash` so the lock actually constrains sizing. This isolates the *one*
correctness defect (proceeds inflate the sizing budget) without adopting the
full margin model — borrow fees, maintenance checks, and forced liquidation stay
off.

**Blast radius. SMALL and gated.** Default-off ⇒ byte-identical to today; no
golden re-pin on merge (mirrors NS1's clean merge, `portfolio.ml:28-31`). When
flipped on, only the short leg's sizing budget changes. Long-only Cell-E is
bit-identical on or off (no shorts → no locks).

**Experiment-flag-discipline.** Cleanest fit. R1: the `false` default reproduces
prior behaviour exactly. R2: expose it as a `Weinstein_strategy.config` field
(via the `portfolio_config` seam that NS1's
`exempt_closing_trades_from_cash_floor` already uses,
`cash-floor-correctness.md` §Completed) so it routes through `Overlay_validator`
and becomes a `Variant_matrix` axis the day it lands. R3: stays off until a
WF-CV experiment on the long-short track returns an ACCEPT.

**Effort. Small-medium.** Reuses `_initial_collateral_for_short` /
`_collateral_release_on_cover` (`portfolio_margin.ml:37-51`); the lock factor
for a no-borrow-fee model could be `1.0` (lock just the proceeds) or `1.5`
(Reg-T-faithful). The only structural edits are: the flag, the conditional
routing, and the `current_cash`→`available_cash` sizing fix. **A1 core**: it
touches `Portfolio`, so it must stay strategy-agnostic (a plain bool/param,
exactly as NS1 threaded its exemption).

### (c) Document a margin-on requirement for short-side backtests

**What it changes.** No code. Add a short-side-backtest checklist note: "any
long-short spec MUST set `margin_config.enabled = true`; running shorts
margin-off produces over-deployed sizing and is not a valid baseline." Possibly
add a guard/warning when a spec has a short leg but margin off.

**Blast radius. NONE** (docs only). But it does not fix the `current_cash`
sizing-snapshot bug — even with margin on, `portfolio_risk.ml:173` still reads
`current_cash`, so option (c) alone is insufficient unless paired with that
one-line sizing fix.

**Experiment-flag-discipline.** N/A (no mechanism).

**Effort. Trivial**, but leaves the defect latent and relies on every future
spec author remembering the rule.

---

## 3. Recommendation

**Recommend option (b): reserve short proceeds as locked collateral in the
non-margin path, behind a default-off flag — paired with the
`current_cash`→`available_cash` sizing fix.**

Rationale:

1. **It isolates the actual defect.** The bug is "short proceeds inflate the
   sizing budget." Option (b) fixes exactly that and nothing else, the way NS1
   isolated the closing-trade floor exemption. Option (a) bundles the fix with
   borrow-fee accrual, maintenance margin, and forced-liquidation
   path-dependence — a much larger behaviour change that should be its own,
   separately-validated step (and whose faithful FINRA-tier form isn't even
   implemented yet, `long-short-margin-mechanics` §4).
2. **Safe merge, full discipline.** Default-off ⇒ no golden re-pin (R1);
   exposed as a `Weinstein_strategy.config` axis (R2); promotion gated on a
   WF-CV ACCEPT (R3). It matches the NS1 pattern the track has already proven.
3. **Smallest A1 blast radius.** A single bool threaded into core `Portfolio`,
   strategy-agnostic, plus a one-line sizing read swap.

**This is moot for the long-only Cell-E baseline and matters only for the
long-short track.** With no shorts, no collateral is ever locked, so the flag is
a no-op on or off — Cell-E results are unaffected regardless.

**Sequencing: run it parallel to the long-short work, do not block on it.** The
long-short track can scaffold (entry/exit logic, short universe gate) without
NS2; NS2 is the correctness gate the long-short *baseline* must clear before any
short-side experiment is trustworthy. Land the default-off flag now so it is an
axis; flip it on (and pin the corrected long-short baseline) as the first step
of long-short validation. Note that the `current_cash`→`available_cash` sizing
fix is the load-bearing half — without it the lock has no effect on sizing.

---

## 4. Out of scope / open questions for the maintainer

This is the genuine design fork the human should ratify before implementation:

1. **Lock factor in the non-margin path.** Should the flag lock `1.0×` proceeds
   (a minimal "proceeds aren't free buying power" correction) or `1.5×`
   (Reg-T-faithful: proceeds + 50% new equity, `long-short-margin-mechanics`
   §1.1)? `1.0×` is the smallest honest fix; `1.5×` is more realistic but
   constrains sizing harder and is arguably "half a margin model." My lean:
   `1.5×` for faithfulness, but this is a deliberate call.

2. **(b) vs (a) long-term.** Option (b) is a deliberately partial model (no
   borrow fee, no maintenance, no forced liquidation). Is that acceptable as the
   long-short baseline, or does the maintainer want the full Reg-T/FINRA model
   (`long-short-margin-mechanics` §4) before trusting *any* short-side number?
   If the latter, (b) is a stepping-stone, not the destination — and we should
   say so when landing it.

3. **The `current_cash`→`available_cash` sizing fix is independently correct.**
   Even under (c), reading `current_cash` for short sizing is wrong once any
   collateral exists. Should that one-line fix land *unconditionally* (it is a
   no-op while `locked_collateral` is always 0), decoupled from the flag? It
   carries no blast radius today and de-risks every later option.

4. **Should a short-leg-with-margin-off spec emit a warning?** Independent of
   the chosen option, a guard that flags "short positions present but no
   collateral model active" would prevent silently-invalid baselines. Cheap;
   worth doing alongside whichever option lands.
