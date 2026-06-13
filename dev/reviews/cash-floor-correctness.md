Reviewed SHA: 31c942213975493819bf8ca272c9648cea6492c1

# QC Review — cash-floor-correctness (NS1, PR #1567)

`feat(portfolio): NS1 cash-floor closing-trade exemption`

(Structural review was posted as a PR review comment; behavioral section follows.)

## Behavioral QC — NS1 cash-floor closing-trade exemption

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test | PASS | `portfolio_cash_floor.mli`: (a) flag-off byte-identical → `cover_rejected_when_exemption_off`; (b) genuinely-reducing accepted unconditionally → `full_cover_exempt_when_flag_on`, `partial_cover_exempt_when_flag_on`; (c) over-cover exempts closing portion, floor applies to opening portion → `over_cover_opening_portion_faces_floor` (rejected) + `over_cover_small_opening_portion_accepted` (accepted). `portfolio.mli` `create` default-false → `test_create_portfolio` pins the field=false. `portfolio_risk.mli` axis seam → `test_cash_floor_exemption_nested_axis_expands`. |
| CP2 | Each PR-body "Test plan" claim has a corresponding committed test | PASS | PR body lists: default-off no-op → `cover_rejected_when_exemption_off`; full cover exempt → `full_cover_exempt_when_flag_on`; partial cover exempt → `partial_cover_exempt_when_flag_on`; over-cover opening faces floor (rejected)/small opening accepted → `over_cover_opening_portion_faces_floor`/`over_cover_small_opening_portion_accepted`; long-sell reducing exempt → `long_sell_reducing_is_exempt`; nested axis expands+validates → `test_cash_floor_exemption_nested_axis_expands`. Every advertised test exists in the committed files and is in the test runner's `-list-test` output (verified: 6 portfolio cases × {AverageCost, FIFO} = 12; plus the axis case). No advertised-but-missing test. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | The R1 backward-compat invariant ("flag-off ⇒ behaviour bit-identical") is pinned at the unit level by `cover_rejected_when_exemption_off` asserting `is_error` on the exact trade the legacy floor rejects, and at the integration level by R1 default-off (full `dune runtest` exit 0, no golden re-pin). Acceptance tests assert full post-trade state (`current_cash` via `float_equal`, `unrealized_pnl_per_position` via `is_empty`, `position_quantity` via `float_equal`) — not just counts. |
| CP4 | Each guard in code docstrings has a test exercising the guarded scenario | PASS | The over-cover split guard ("over-cover is NOT blanket-exempt; new-opening portion still faces the floor") is exercised on both sides of the boundary: `over_cover_opening_portion_faces_floor` (opening portion breaches → rejected) and `over_cover_small_opening_portion_accepted` (opening portion small → flip accepted, position → +20). The negligible-quantity epsilon path (genuinely-reducing → `Ok` unconditionally) is exercised by full + partial cover. |

### Behavioral Checklist (domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core Portfolio modification is strategy-agnostic | PASS | The change is a plain `bool` field on `Portfolio.t`, defaulting `false`, threaded in via `create`. The exemption logic in `Portfolio_cash_floor` is purely a function of trade vs position sign/quantity (`_is_closing`, `min(|trade_qty|,|existing_qty|)` split) — no Weinstein/stage/strategy concept appears. `trading/portfolio/lib/dune` libraries = `core trading.base core_unix.time_ns_unix status` — no `weinstein.*`, no `portfolio_risk`, no `strategy`. The Weinstein seam lives entirely in `Portfolio_risk.config` (analysis layer) and is wired through `Simulator.create_deps` → `Portfolio.create` as a bool. Generalizes to ANY strategy. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein stage / stop / screener / macro domain rows | NA | Portfolio solvency infra change; no stage/stop/screener domain logic. The exemption operates on signed quantities and cash, not on any Weinstein decision rule. |
| W1 | Weinstein-faithful spine intact | PASS | A portfolio-level cash-floor exemption does not touch any spine item (stage classification, Stage-2-only entry, breakout+volume entry, Stage-3/4 exit, initial stop below base/MA, macro+sector gate, RS selection). It only changes when the solvency check rejects a *reducing* trade. Spine untouched. |
| R1 | Default-off on merge | PASS | `exempt_closing_trades_from_cash_floor : bool [@sexp.default false]` on both `Portfolio.t` (via `create` default) and `Portfolio_risk.config` (`default_config = false`). Behavioral confirmation: flag-off path delegates `checked_change := cash_change` (full trade faces floor) — byte-identical to the prior `_check_sufficient_cash`; pinned by `cover_rejected_when_exemption_off` + full `dune runtest` exit 0 with no golden re-pin. |
| R2 | Searchable as a config axis | PASS | Real `Portfolio_risk.config` field (not a hardcoded constant), reached as the `portfolio_config` seam of `Weinstein_strategy.config`. `test_cash_floor_exemption_nested_axis_expands` pins that `portfolio_config.exempt_closing_trades_from_cash_floor` expands through `Variant_matrix`/`Overlay_validator` to the expected override sexp for both `true` and `false`. |
| R3 | No default-on without an ACCEPT | PASS | Default stays `false`; PR body explicitly defers promotion to the NS4 WF-CV experiment (human-gated). No ledger ACCEPT cited and none needed — nothing flips on. |

### A1 generalizability verdict

The core `Portfolio` change is strategy-agnostic. The exemption is a function of trade-vs-position sign/quantity only; the flag is a plain bool threaded `Portfolio_risk.config` → `Simulator.create_deps` → `Portfolio.create`; core `Portfolio`'s dune declares no dependency on any Weinstein/strategy/`portfolio_risk` module. The exemption would behave identically for any strategy that sets the bool. **A1 = PASS.**

## Quality Score

5 — Clean module extraction (no limit bumps), exhaustive contract pinning (default-off no-op, full/partial cover, over-cover split on both sides of the boundary, long-sell generalization, nested axis), and a correctly strategy-agnostic core change with the Weinstein seam isolated in the analysis layer.

## Verdict

APPROVED
