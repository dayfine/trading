# Concentration / winner-rebalance refinement — plan — 2026-06-10

**User direction (2026-06-10, overnight):** the AXTI $6.69M position (78% of NAV)
is the strategy *working* — catching and riding a Stage-2 monster is the goal, and
the fill is liquid+real (`dev/notes/trade-realism-liquidity-findings-2026-06-10.md`,
$1B/day, float ~10-20% of a $5-10B cap = normal). The legitimate concern is
**concentration / rebalancing**, "worth refining."

## The gap

`portfolio_config.max_position_pct_long` (0.14 in Cell-E) caps a position's size
**at entry only**. As a winner appreciates it is never re-checked, so a 36× winner
grows to 78% of NAV. The portfolio carries undiversified single-name tail risk even
though every individual fill is realistic.

This is distinct from liquidity (a non-issue at our scale) and from selection (the
cascade-reweight work). It is a **risk-overlay / position-management** question.

## Weinstein-faithfulness

The spine says *let winners run* — exit on Stage 3/4 or a trailing-stop break, not
on an arbitrary profit target (`.claude/rules/weinstein-faithful-core.md`). A hard
periodic rebalance to equal weights is **anti-doctrine** and out of scope. But
Weinstein also *diversifies* (several positions, position-sized) and does not
advocate 78%-in-one-name. The faithful refinement is a **soft concentration cap**:

> When a single position exceeds `max_single_name_nav_pct` of NAV, trim the
> **excess only** (partial sell back to the cap), keeping the position open (still
> subject to the normal Stage-3/4 / trailing-stop exit). Freed capital re-enters
> the normal screener→sizing pipeline (other Stage-2 candidates).

This keeps the winner ridden while bounding tail risk — a position-sizing dial, not
a new exit rule. It is the ongoing analogue of the entry cap that already exists.

## ⚠ Build-scoping finding (2026-06-10): partial trim needs a CORE change

The transition model (`trading/trading/strategy/lib/position.mli`) supports only a
**whole-position** `TriggerExit { exit_reason; exit_price }` — there is no
transition that initiates a *partial* exit. The `Exiting` state carries a
`target_quantity` field, but `TriggerExit` always targets the full position (the
engine sets `target_quantity = full quantity`). The existing trim runners
(`macro_bearish_trim_runner`, `force_liquidation_runner`) achieve exposure control
by exiting **whole** weakest-RS positions until under a cap — acceptable for
total-exposure control, **too blunt for single-name concentration** (it would dump
the entire AXTI monster the moment it crossed the cap, defeating let-winners-run).

A faithful *partial* trim therefore requires a **core position-model + engine +
simulator change**: add a `target_quantity` to `TriggerExit` (or a new
`TriggerPartialExit { target_quantity; … }`), plus engine/simulator handling to
reduce a `Holding` to `quantity − trim` and keep the remainder `Holding` (the
`ExitFill` path already supports partial `filled_quantity`, so the fill mechanics
exist — the gap is the *initiating transition* and the post-fill "return to
Holding" instead of "Closed"). This touches the A1 core watch-list
(`trading/trading/strategy/`, `engine`, `simulation`) → **propose as a decision
item per CLAUDE.md, not a unilateral feature PR.**

**Recommended path:** (1) land the core partial-exit transition as its own small,
strategy-agnostic PR (decision item — it is generally useful, not Weinstein-
specific); (2) then build the concentration-trim runner on top as a default-off
Weinstein dial. Until (1) lands, the only buildable version is the crude
full-exit-on-cap (mirrors `macro_bearish_trim`, no core change) — usable as a
**directional probe** of the tradeoff (full exit = the most aggressive trim = a
lower bound on the partial-trim benefit), but not the shippable mechanism.

## Mechanism (default-off config dial, per experiment-flag-discipline)

`portfolio_config.max_single_name_nav_pct : float [@sexp.default 0.0]` where `0.0`
= disabled (no-op, current behaviour). When `> 0.0`, on each rebalance cadence
(weekly, aligned with the existing strategy cadence), for any held name whose
`position_value / nav > cap`, emit a partial-sell transition trimming the excess.

Open design questions to resolve before building:
- **Cadence**: trim on the weekly `on_market_close` (same as other transitions) —
  avoids intraday churn, matches the strategy's weekly decision rhythm.
- **Hysteresis**: trim only when meaningfully over (e.g. `nav_pct > cap × 1.1`) to
  avoid thrashing a position that hovers at the cap. A `rebalance_band` param.
- **Tax/cost**: each trim is a taxable, cost-incurring partial sale — the cost
  model already prices `bid_ask_spread_bps`; the WF-CV will reflect it.
- **Interaction with the trailing stop**: trimming reduces the position but the
  stop tracks the remaining shares — no conflict; verify the stop state machine
  handles a quantity reduction (it should — partial fills already exist).

## Experiment

Surface `max_single_name_nav_pct ∈ {0.0 (baseline), 0.25, 0.35, 0.50}` on top-3000
Cell-E (the universe where the concentration actually arises — top-1000 large-caps
rarely 36×). First a single full-period backtest comparison to see the
return-vs-concentration tradeoff (does diversified redeployment of trimmed capital
beat the concentrated hold?), then WF-CV if promising, then the confirmation grid.

**Metrics that matter here** (beyond return/Sharpe): **max single-name NAV%** over
the run (the thing we're capping), **time-underwater / Ulcer** and **MaxDD** (does
bounding concentration reduce the drawdown tail?), and the **realised-vs-unrealised
split** (trimming converts unrealised AXTI-style marks into realised gains +
redeployable capital — arguably more robust per
`project_broad_universe_790_mtm_inflated`'s unrealised-mark concern). A cap that
holds return while cutting MaxDD / single-name% is a clean win even if mean return
dips slightly.

## Priority

Parallel to / after the cascade-reweight WF-CV. The two are independent levers
(selection vs position-management) and compose. The core partial-exit transition
(decision item) gates the faithful build; the crude full-exit probe can run sooner.
