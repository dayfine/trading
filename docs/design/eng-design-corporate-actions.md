# Engineering design — corporate actions (M&A track)

**Status**: design draft, 2026-05-07. Companion to PR #916 (P1 stale-hold detector,
which addresses the artefact-corruption symptom but not the underlying corporate
actions). Drives the long-term work the user flagged in the PR #916 conversation:
"long term maybe handling M&A would be helpful".

---

## Why this exists

The simulator currently has no model of corporate actions beyond stock splits.
Concretely:

- **Splits** are detected and handled in `Trading_simulation.Simulator`
  (`_detect_splits_for_held_positions` + `_apply_split_events` +
  `_apply_split_to_position`). Both the broker portfolio and the strategy-side
  `Position.t` map are scaled in lockstep on the split date. Tested
  end-to-end via `test_split_day_*.ml`.
- **Mergers, spinoffs, ticker renames, bankruptcies, suspensions** — the
  simulator has no model. When bars stop arriving for a held position, the
  simulator now (post-PR #916) detects the staleness via
  `Trading_simulation.Stale_hold` and emits a record into
  `stale_holds.sexp`, but the position is **not** force-closed; it is
  forward-filled at the last-known close. P1's resolution was deliberately
  detector-only, deferring the closer to this design.

Result: a 16-year SP500 backtest (Cell E, PR #913) accumulates 14 stuck
positions by run end (ANDV→MPC merger 2018-10, AGN→AbbVie 2020, SVU→UNFI
2018, etc.). Each ghost position distorts:

- `final_portfolio_value` (forward-fill freezes the last close indefinitely)
- `Sharpe` / `MaxDD` / `CAGR` (computed off the equity curve that includes
  those frozen positions)
- `open_positions.csv` reconciler artefact (lists positions that no longer exist
  on any exchange)

P1 unblocks the artefact-truncation symptom; this design closes the
ghost-position behaviour.

---

## Status quo summary

| Event             | Detection                             | Position action               | Strategy notified       |
| ----------------- | ------------------------------------- | ----------------------------- | ----------------------- |
| Stock split       | `Split_detector.detect_split`         | scale qty + price (lockstep)  | strategy sees new state |
| Cash merger       | none                                  | none — position frozen        | none                    |
| Stock merger      | none                                  | none — position frozen        | none                    |
| Spinoff           | none                                  | none — position frozen        | none                    |
| Bankruptcy        | none                                  | none — position frozen        | none                    |
| Suspension        | `Stale_hold` (PR #916, recorder only) | none — position forward-fill  | none                    |
| Ticker rename     | partial (`wiki_sp500.ticker_aliases`) | none in simulator             | none                    |
| Delisting (other) | partial (`Stale_hold`)                | none — position forward-fill  | none                    |

Universe-construction layer **does** know about delistings (per
`eng-design-data-universe.md`). The data layer carries
`Instrument_info.delisting_date` and a hand-curated `ticker_aliases` table for
~7 well-known SP500 renames. Neither flows into the simulator.

---

## Target event taxonomy

```ocaml
type event_kind =
  | Cash_merger of { cash_per_share : float }
      (** Target shareholders receive [cash_per_share * quantity] in cash;
          position closes at cash price on the merger date. The classic
          "all-cash deal" — e.g. Microsoft/LinkedIn, Berkshire/PCP. *)
  | Stock_merger of {
      acquirer_symbol : string;
      exchange_ratio : float;
        (** Shares of acquirer received per share of target. *)
      cash_per_share : float;
        (** Cash leg, possibly 0.0 for pure stock deals. *)
    }
      (** Mixed cash + stock deal. Target shareholders receive
          [exchange_ratio * quantity] shares of acquirer plus
          [cash_per_share * quantity] in cash. Pure stock deals are this
          variant with [cash_per_share = 0.0]. ANDV→MPC was 1.87 MPC + $35.70
          cash per ANDV share. *)
  | Spinoff of {
      child_symbol : string;
      child_shares_per_parent : float;
        (** Shares of new entity received per share of parent. Parent
            position retained at adjusted cost basis. *)
    }
      (** Holder retains parent + receives [child_shares_per_parent * quantity]
          of the new entity. e.g. PYPL spun out of EBAY 2015-07. *)
  | Bankruptcy
      (** Position closes at zero; cost basis fully written off as
          realized loss. Same accounting as a Cash_merger with
          [cash_per_share = 0.0] but classified separately for
          diagnostics + tax accounting downstream. *)
  | Ticker_rename of { new_symbol : string }
      (** Same security, new symbol. Position swaps symbol; quantity,
          cost basis, lots all unchanged. Already partially covered by
          `wiki_sp500.ticker_aliases` for ~7 SP500 cases. *)
  | Delisting_other
      (** Suspension, voluntary delisting, going-private — no shareholder
          payout but trading stops. Position closes at the last known
          close price on the last trade date. Pessimistic but
          conservative; captures the practical "you can't sell anymore"
          reality. *)

type event = {
  symbol : string;
  effective_date : Date.t;
      (** Date the action took effect. Position handling fires on this
          date's close (consistent with how splits are applied). *)
  kind : event_kind;
  source : source;
      (** Provenance — vendor/curated/derived. Affects confidence in the
          run's output. *)
}
```

---

## Vendor strategy

The data we need:

1. Per-symbol effective date.
2. Per-symbol kind + parameters (cash, ratio, acquirer, etc.).
3. Coverage from the simulation start (2010 in current usage).

### Available sources

| Source                      | Coverage                | Structure       | Cost           | Notes                                          |
| --------------------------- | ----------------------- | --------------- | -------------- | ---------------------------------------------- |
| EODHD `?delisted=1`         | All US equities         | `last_price_date` only | included        | No M&A terms — last bar date only              |
| EODHD `fundamentals/<sym>`  | Per symbol              | `IsDelisted`, `DelistedDate` | included | Per-symbol; rate-limited; no acquirer either   |
| Wikipedia "Selected changes" | SP500 only             | parsed prose    | free           | Already wired (`wiki_sp500.changes_parser`)    |
| `wiki_sp500.ticker_aliases` | 7 hand-curated SP500    | OCaml table     | free           | Captures stock-merger ratios for major SP500   |
| Norgate Data                | Full North America      | structured      | $$$ subscription | "Database of corporate actions"               |
| SEC EDGAR 8-K filings       | Public US issuers       | filing PDFs     | free           | Heavy parsing; M&A in items 1.01 / 2.01 / 8.01 |
| Manual ticker_aliases       | Whatever we curate      | OCaml table     | free           | Highest precision; unbounded labour cost       |

### Recommendation

Two-tier:

1. **Tier-1 (delisting detection)**: EODHD `exchange-symbol-list/US?delisted=1` plus
   `fundamentals/<sym>::General::IsDelisted` + `DelistedDate`. Universal coverage of
   "this symbol stopped trading on date X". Wired as new endpoints in
   `analysis/data/sources/eodhd/lib/`. Result: every held position with no bars
   beyond `DelistedDate` is classifiable as `Delisting_other` with high confidence.

2. **Tier-2 (M&A terms)**: hand-curated extension of `wiki_sp500.ticker_aliases`
   to a generic `corporate_actions.csv` (or `.sexp`), seeded from:
   - Existing `wiki_sp500.ticker_aliases` (7 entries).
   - Wikipedia "Selected changes" page for SP500 deltas after 2010.
   - SEC EDGAR scrape for non-SP500 deltas the strategy actually held in
     a backtest (run-driven; only enrich symbols that show up in
     `stale_holds.sexp`).
   - Manual top-up from financial press for high-conviction M&A.

   Result: M&A terms (ratio, acquirer, cash leg) for the symbols the strategy
   actually trades. Coverage is "as good as the curated table"; uncovered
   stale-held symbols fall through to Tier-1's `Delisting_other` with the
   last-close-price fallback (lossy but bounded).

Tier-3 (Norgate / commercial vendor) is the right answer if/when the
strategy starts trading deeply outside SP500 and the curated table can't keep
up. Defer until strategy expansion forces it.

---

## Storage layer

New module `analysis/data/types/lib/corporate_action.ml` carrying the `event`
type above. Persistence as `data/corporate_actions/<symbol>.sexp` files —
one per symbol, with a list of events ordered by date. Mirror's existing
`analysis/data/storage/` shape (per-symbol files, first+last-char hashed dirs).

Bulk-fetch script `analysis/scripts/fetch_corporate_actions.ml` (analogous to
`fetch_symbols.exe`):

- Tier-1: pull EODHD delisted symbols + per-symbol fundamentals delisting metadata.
- Tier-2: read curated `data/corporate_actions_curated.sexp` and merge.
- Output: per-symbol sexp files in `data/corporate_actions/`.

Inventory check via `dev/scripts/check_corporate_actions_coverage.sh` — analogous
to broad-universe coverage check.

---

## Simulator integration

New module `Trading_simulation.Corporate_action_runner`:

```ocaml
val detect : adapter:Market_data_adapter.t
          -> portfolio:Portfolio.t
          -> date:Date.t
          -> event list
(** On every step, walk held positions; for each (symbol, today) with an
    effective corporate-action event, emit it. Source: a per-symbol event
    cache loaded from data/corporate_actions/ at adapter init time. *)

val apply : event -> portfolio:Portfolio.t -> positions:Position.t Map.M(String).t
         -> Portfolio.t * Position.t Map.M(String).t * trade list
(** Apply one event: synthesises the appropriate trades + position
    updates. Pure — returns updated state. *)
```

Wired into `Simulator.step` between the existing split-detection block and
the `_get_today_bars` call:

```ocaml
let split_events = _detect_splits_for_held_positions t in
let portfolio = _apply_split_events t.portfolio split_events in
let positions = _apply_splits_to_positions t.positions split_events in
(* NEW: corporate actions *)
let ca_events = Corporate_action_runner.detect ~adapter ~portfolio ~date in
let (portfolio, positions, ca_trades) =
  List.fold ca_events ~init:(portfolio, positions, [])
    ~f:(fun (p, pos, ts) ev ->
      let (p', pos', ts') = Corporate_action_runner.apply ev ~portfolio:p ~positions:pos in
      (p', pos', ts @ ts'))
in
let today_bars = _get_today_bars t in
...
```

### Per-event handler

| Kind             | Trade synthesised                                     | Position update                                       |
| ---------------- | ----------------------------------------------------- | ----------------------------------------------------- |
| `Cash_merger`    | `Sell` at `cash_per_share`                            | Position → `Closed`; cash credited                    |
| `Stock_merger`   | `Sell` of target at `cash_per_share` (cash leg) plus `Buy` of acquirer at the ratio-implied price (stock leg) | Target → `Closed`; new `Holding` of acquirer at scaled cost basis |
| `Spinoff`        | None on parent; new `Holding` of child at split-derived cost basis | Parent retained, cost basis adjusted; new child position created |
| `Bankruptcy`     | `Sell` at 0.0                                         | Position → `Closed`; cash unchanged (full loss)        |
| `Ticker_rename`  | None                                                  | Position symbol swapped in place; lots, qty, basis unchanged |
| `Delisting_other`| `Sell` at last known close                            | Position → `Closed`; cash credited at last close      |

All synthesised trades flow through `_apply_trades_best_effort` so portfolio
accounting matches the existing trade path. Position state transitions go
through `Position.apply_transition` so the strategy sees the same
`Closed` event it would on a normal exit.

---

## Strategy notification

Strategy receives the closure transition like any other exit. New
`exit_reason` variant:

```ocaml
type exit_reason =
  | StrategySignal of { label : string; detail : string option }
  | StopLoss
  | TakeProfit
  | TimeExpired
  | CorporateAction of event_kind   (* NEW *)
```

`label` consumers (e.g. `trades.csv`'s `exit_trigger` column) get explicit
labels: `cash_merger`, `stock_merger`, `spinoff`, `bankruptcy`,
`ticker_rename`, `delisting_other`. Lets release-gate consumers count
strategy-driven exits separately from corporate-action exits.

---

## Output artefacts

New backtest outputs (additive — old artefacts unchanged):

- `corporate_actions.sexp`: list of every `event` that fired during the run.
  Empty file when no events fired (the common case for a small-window backtest
  on a clean-universe scenario).
- `Summary.t.corporate_action_count : int` (per-kind counter exposed in
  `summary.sexp` for release-gate consumers).
- `trades.csv`'s `exit_trigger` column gains the new labels.

`stale_holds.sexp` (P1) is retired once corporate-actions coverage is
universal — it becomes redundant. Keep it during the rollout as a safety
net; remove it in the cleanup PR after coverage is verified ≥99% on a
multi-year run.

---

## Test plan

### Unit tests

- `Corporate_action.event` sexp roundtrip; per-kind constructors.
- `Corporate_action_runner.apply` per-kind: synthesised trade + position
  update + cash flow, validated end-to-end against hand-computed expected
  values.

### Synthetic integration

`test_corporate_action_runner.ml`:

- 1-symbol portfolio + cash-merger event → position closes at cash price,
  cash credited correctly.
- 1-symbol portfolio + stock-merger event → target closed, acquirer position
  opened at scaled cost basis, cash leg credited.
- 1-symbol portfolio + bankruptcy event → position closes at 0, full
  cost-basis realized loss in `trades.csv`.
- 1-symbol portfolio + ticker-rename event → position symbol swaps, no
  trades, lots preserved.

### End-to-end golden

`tests_data/backtest_scenarios/goldens-sp500-historical/sp500-2018-merger-andv.sexp`
— a focused 6-month window covering 2018-09 to 2019-03, ANDV held into the
2018-10-01 MPC merger. Expected:

- Pre-merger: ANDV in `Holding` state.
- 2018-10-01: `Stock_merger` event fires. ANDV → `Closed` with exit at
  `1.87 * MPC_open + 35.70 / share`. New MPC `Holding` at cost basis derived
  from ANDV's cost.
- Post-merger: MPC position behaves normally; subsequent stop / laggard /
  Stage-3 exits apply.
- `corporate_actions.sexp` records exactly one event.
- `trades.csv` shows the synthesised ANDV close with `exit_trigger =
  stock_merger`.

### Regression

After this lands, re-run the 16y Cell E backtest (PR #913 baseline). Expected:

- `stale_holds.sexp` count drops from current ~14 to ≤2 (the residual is
  whatever Tier-2 curation hasn't covered yet).
- `corporate_actions.sexp` count shows the historical merger volume of
  the held universe over 16y.
- `final_portfolio_value` and Sharpe shift modestly — the ghost positions
  were forward-filled, so closing them at cash/ratio prices changes the
  reconciled NAV by roughly the difference between the merger price and
  the last-bar close. Magnitude TBD; pin via comparison run.

---

## Phasing

PR-A (~250 LOC): types + storage layer + ingest CLI scaffold. No simulator
wiring yet. Tests on the type machinery + sexp roundtrip.

PR-B (~300 LOC): EODHD `?delisted=1` endpoint + per-symbol delisting
metadata. Enables Tier-1 detection. Curated table seed (the existing 7
SP500 entries from `ticker_aliases`).

PR-C (~400 LOC): `Corporate_action_runner` + simulator wiring + per-event
handlers + unit tests. Stale_hold remains the safety net.

PR-D (~200 LOC): backtest result writer integration; `corporate_actions.sexp`;
`trades.csv` `exit_trigger` extension; `Summary.corporate_action_count`.

PR-E (~150 LOC): ANDV→MPC golden scenario + end-to-end test. Re-pin Cell E
baseline with corporate-action coverage on.

PR-F (~100 LOC): once Cell E reconciles cleanly, retire `stale_holds.sexp`
in favour of the more specific event log. Document migration path.

Total ≈ 1400 LOC across 6 PRs. Each independently mergeable; PR-A through
PR-D land the infrastructure; PR-E validates; PR-F is cleanup.

---

## Out of scope (this design)

- **Corporate actions in real-time live trading**. The simulator handler is
  reusable; live broker integration belongs in a separate "live mode" doc.
- **Tax-lot accounting** on stock mergers. The implementation tracks cost
  basis at portfolio level; per-lot wash-sale / cap-gains accounting is a
  separate concern in `analysis/scripts/realized_pnl_tax.ml` (not yet built).
- **Pre-merger arbitrage** strategies (long target + short acquirer ratio).
  The Weinstein system is long-only and trend-following; merger-arb belongs
  in a different strategy.
- **Pension / dividend reinvestment plans (DRIP)**. Dividends are a separate
  data feed (`Dividends_endpoint`) and worth a parallel design when
  dividend-aware strategies are in scope.
- **Rights / warrant issues** mid-position. Rare enough in SP500 history
  that we'll handle on a case-by-case basis if/when one trips a backtest.

---

## Open questions

1. **What price does `Stock_merger`'s acquirer leg fill at?** Options:
   - Acquirer's open-of-merger-date price (broker-style).
   - Acquirer's open of the day after the merger (T+1 settlement).
   - Cost-basis-preserving derived price.
   The `1.87 * MPC_open` formulation in the test plan above implies open-of-day.
   Verify against actual broker mechanics for ANDV→MPC.

2. **Does `Spinoff` need explicit handling?** Few Weinstein-strategy candidates
   spin off (the strategy targets Stage-2 advances; spinoffs disrupt that).
   Could defer until first time the strategy holds a parent through a spinoff.

3. **Where do the curated tables live in source?** Single
   `data/corporate_actions_curated.sexp` checked into the repo, or a
   per-symbol set under `data/corporate_actions/<sym>.sexp`? The
   per-symbol shape mirrors existing storage (price bars, splits) and
   composes cleanly with the bulk-fetch model. Recommendation: per-symbol.

4. **Should `Stale_hold` retire or co-exist?** Keeping it as a safety net
   guards against curated-table gaps (we won't have 100% coverage on day
   one). Retire only after a multi-year run shows zero stale-hold events.

5. **`enable_corporate_actions` config flag?** Default ON is the right
   long-term answer (these are real economic events). But for backwards
   compatibility with existing pinned baselines, ship default OFF for one
   release cycle, re-pin baselines under the new defaults, then flip on.

---

## References

- PR #916 — P1 stale-hold detector (the artefact-corruption fix; this design
  is the closer).
- PR #813 — Wiki+EODHD historical universe (`Instrument_info.delisting_date`
  context).
- `analysis/data/sources/wiki_sp500/lib/ticker_aliases.ml` — existing
  hand-curated table; first 7 entries seed Tier-2.
- `dev/notes/data-gaps.md` §broad-universe-coverage — coverage measurement
  pattern to mirror for corporate-actions coverage.
- `docs/design/eng-design-data-universe.md` — listing/delisting metadata
  on `Instrument_info`.
- `docs/design/weinstein-trading-system-v2.md` — system context.
