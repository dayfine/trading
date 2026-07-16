# M1 — Long buying power + priced margin interest (iteration 0)

**Track:** margin-realism. **Binding spec:** `dev/plans/levered-longshort-margin-realism-2026-07-14.md` §M1.
**Sizing note in dispatch:** keep < ~700 LOC; split M1a/M1b if larger, ship M1a.

## Context

Two orthogonal margin mechanisms exist today, neither models a *levered long book*:

- `Trading_portfolio.Margin_config` (#859/#1266) — SHORT-side only: initial
  collateral, maintenance force-cover, flat 50bps borrow fee. Applied per-tick in
  `Margin_runner.tick` / `Portfolio_margin.accrue_daily_borrow_fee`.
- `max_long_exposure_pct_entry` (#1965) — LONG-side only: an entry-walk ceiling on
  committed-at-entry (entry-price-denominated) long notional vs marked NAV.
  Computed in `Screening_notional.make_entry_walk_state` (the `long_notional_cap`
  field of `entry_walk_state`), enforced in
  `Entry_audit_capture.check_long_notional_cap`. Default `0.0` → cap `Float.infinity`
  (exact no-op). This is currently the ONLY thing bounding short proceeds levering
  the long book.

§M1 asks to **generalize the #1965 cap seam into a buying-power model** (do not
build a parallel mechanism) and to **price margin interest on debit balances**.

## Approach

`initial_long_margin_req` is the leverage dial: `1.0` = cash account (Reg-T 100%),
`0.5` = 2× buying power. The entry ceiling becomes `min(exposure_term, margin_term)`
where `margin_term = equity / initial_long_margin_req`.

**The R1 crux (default must change nothing).** The plan's §M1 says "default 1.0 =
cash account = current cap-1.0 semantics" AND "flag-discipline R1: defaults change
nothing." Those are in tension if `req = 1.0` literally imposes an `equity` ceiling
— the pre-M1 default had *no explicit* long ceiling (`max_long_exposure_pct_entry = 0.0`
→ `infinity`); a new `equity` ceiling would block the legitimate held-winner-
appreciation-above-NAV and short-proceeds cases that #1965 deliberately leaves to the
*explicit opt-in* `max_long_exposure_pct_entry`. R1 is binding, so:

- `initial_long_margin_req >= 1.0` (cash account) → `margin_term = infinity`
  (no explicit equity ceiling; new-long funding stays bounded by the implicit
  available-cash gate, exactly as pre-M1). The `equity`-ceiling "cap-1.0 semantics"
  remain reachable via the existing `max_long_exposure_pct_entry = 1.0` knob.
- `0.0 < req < 1.0` → `margin_term = equity / req` (leverage headroom above equity).
- Combined ceiling = `min(exposure_term, margin_term)` — "min of the two applies."

At defaults (`exposure 0.0`, `req 1.0`) both terms are `infinity` ⇒ ceiling
`infinity` ⇒ **bit-identical** to today. E-capped (#1965, exposure `1.0`, req `1.0`)
is also preserved exactly (`min(equity, infinity) = equity`).

**Interest.** `long_margin_rate_annual_pct` (default `0.0`) prices a positive debit
balance at `debit * annual/252` per trading day (reusing
`Margin_config.trading_days_per_year` for consistency with the short borrow fee).
Pure primitives only in M1a; the per-tick simulator accrual + the cash-gate
relaxation that actually *creates* debits (funding longs beyond cash up to the
buying-power ceiling) is **M1b** — without it both the leverage headroom and the
interest are inert (the implicit cash gate binds first, debit stays 0). Landing the
primitives + config now establishes the priced-debit convention R1-safely and makes
both knobs searchable axes the day they land (R2).

### Rejected alternatives

- **`req = 1.0` → `equity` ceiling by default.** Violates R1 (would newly cap the
  #1965 short-proceeds / marked-winner artifact by default). Rejected; the `equity`
  ceiling stays an explicit opt-in via `max_long_exposure_pct_entry`.
- **Wire interest + cash-gate relaxation into the simulator now.** Pushes the PR well
  past the ~700-LOC cap and touches core `Portfolio` / `Simulator` (A1). Deferred to
  M1b so M1a stays a clean, reviewable, R1-safe unit per the split instruction.
- **Put the ceiling math inline in `screening_notional`.** A pure numeric module
  (`Long_buying_power`) is independently testable and reused by M1b's cash-gate work.

## Files to change

- **NEW** `trading/trading/weinstein/strategy/lib/long_buying_power.{ml,mli}` — pure
  numeric buying-power model: `long_notional_ceiling`, `daily_long_margin_rate`,
  `long_margin_interest_charge`. No config dependency (scalar args).
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.{ml,mli}` — add
  `initial_long_margin_req : float [@sexp.default 1.0]` +
  `long_margin_rate_annual_pct : float [@sexp.default 0.0]` to the record +
  `default_config` + no-op named constants + docstrings.
- `trading/trading/weinstein/strategy/lib/screening_notional.ml` — replace the inline
  `long_notional_cap` computation with `Long_buying_power.long_notional_ceiling`.
- **NEW** `trading/trading/weinstein/strategy/test/test_long_buying_power.ml` (+ test
  `dune` names entry) — pins ceiling math (default→infinity, exposure/margin/min
  interplay, E-capped equivalence), interest math, and config round-trip/back-compat.
- **NEW** `dev/status/margin-realism.md` — track status file.

## Risks / unknowns

- **Config sexp serialization gains two lines.** `[@sexp.default]` provides read
  back-compat; if any golden pins *serialized* config text it may need a re-pin.
  Mitigated by not comparing serialized config in the new tests and running the
  affected suites to catch it.
- **`Long_buying_power` reusing `Trading_portfolio.Margin_config.trading_days_per_year`**
  keeps 252 out of the code (magic-number linter) and consistent with the short fee.

## Acceptance criteria

- Defaults bit-identical: existing suites untouched + an explicit ceiling-at-defaults
  = `infinity` test. E-capped equivalence pinned.
- Buying-power math pinned (req≥1→infinity term, req<1→equity/req, min-with-exposure).
- Interest accrual pinned (rate 0 → 0; positive debit → `debit*annual/252`; debit≤0 → 0).
- Config round-trip + back-compat parse (old sexp without the fields → defaults).
- `dune build @fmt`, `dune build`, affected test dirs, `dune runtest devtools/checks`
  all green (exit 0). Every `.ml` public fn in `.mli` with a doc comment; no fn > 50 lines.

## Out of scope (M1b and later)

- Per-tick interest accrual in the simulator + the entry-walk cash-gate relaxation
  that creates debit balances (M1b).
- Long-side maintenance / force-reduce (M2), short squeeze robustness (M3),
  validation runs (M4). No default is flipped; no leverage number is quoted.
