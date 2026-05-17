(** Buy-and-Hold benchmark strategy — see [bah_benchmark_strategy.mli]. *)

open Core

type config = { symbol : string } [@@deriving show, eq]

let name = "BuyAndHoldBenchmark"
let default_symbol = "SPY"
let default_config = { symbol = default_symbol }

(** Position id derived from the symbol. Single-position strategy, so a fixed
    suffix is sufficient — there's no second entry to disambiguate against. *)
let _position_id_of_symbol (symbol : string) : string =
  Printf.sprintf "%s-bah-benchmark" symbol

(** Inputs are valid when both cash and price are strictly positive — the only
    configuration where division yields a meaningful share count. *)
let _valid_sizing_inputs ~(cash : float) ~(close_price : float) : bool =
  Float.(cash > 0.0) && Float.(close_price > 0.0)

(** Headroom over today's close to absorb the overnight gap between sizing
    (today) and fill (next trading-day open). The market order generated from
    [CreateEntering] fills at the next bar's open via the engine; if the open
    gaps up by more than the residual cash on a tight floor-divided share count,
    [Portfolio.apply_single_trade] returns [Error "Insufficient cash"], the
    simulator's [_apply_trades_best_effort] silently drops the trade
    (simulator.ml:354-358), and the position stays stuck in [Entering] with 0
    fills — BAH's [_has_position_for_symbol] then suppresses any retry. The
    weekly-start-sweep golden surfaced this as a ~45% zero-trade rate on SPY
    Mondays 2023-2026 (see PR #1167 + fix-forward).

    1% covers gap-ups up to ~1%, which is above the typical SP500 large-cap
    overnight gap. Extreme days (e.g. 2020-03 COVID gaps > 2%) may still reject;
    the proper long-term fix is to make the simulator surface rejected fills
    back to the strategy so retries are possible (filed as a follow-up). *)
let _entry_gap_buffer_pct = 0.01

(** All-cash sizing: convert available cash to whole shares at [close_price].
    Returns [None] when the cash can't buy a single share (price exceeds cash)
    or when inputs are non-positive — both cases should not emit a transition.

    Divides by [close_price * (1 + _entry_gap_buffer_pct)] (not by [close_price]
    directly) so a small overnight gap-up between today's sizing close and
    tomorrow's fill open does not bust the cash budget. See
    [_entry_gap_buffer_pct]'s doc for the failure mode this guards against. *)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if not (_valid_sizing_inputs ~cash ~close_price) then None
  else
    let sizing_price = close_price *. (1.0 +. _entry_gap_buffer_pct) in
    let shares = Float.round_down (cash /. sizing_price) in
    Option.some_if Float.(shares > 0.0) shares

let _entry_reasoning : Position.entry_reasoning =
  ManualDecision { description = "Buy-and-hold benchmark — initial entry" }

let _build_entry_transition ~(symbol : string) ~(price : Types.Daily_price.t)
    ~(target_quantity : float) : Position.transition =
  let kind : Position.transition_kind =
    CreateEntering
      {
        symbol;
        side = Long;
        target_quantity;
        entry_price = price.close_price;
        reasoning = _entry_reasoning;
      }
  in
  {
    Position.position_id = _position_id_of_symbol symbol;
    date = price.date;
    kind;
  }

(** Look up today's bar and size the entry. Returns [None] when there's no price
    for [symbol] today or when the cash can't afford a whole share. *)
let _entry_from_price (price : Types.Daily_price.t) ~(symbol : string)
    ~(cash : float) : Position.transition option =
  match _shares_from_cash ~cash ~close_price:price.close_price with
  | None -> None
  | Some target_quantity ->
      Some (_build_entry_transition ~symbol ~price ~target_quantity)

(* Active (non-[Closed]) position lookup. Skipping [Closed] keeps the
   buy-and-hold idempotency intact only against still-open positions; in
   practice BAH never exits by design, so this is a defensive belt-and-
   suspenders filter alongside the simulator's positions-Map prune (PR #1024).
   Exhaustive pattern mirrors
   [weinstein_strategy_screening.held_symbols]. *)

(** True if any value in [positions] points at [symbol]. The simulator keys its
    position map by [position_id] (e.g. ["SPY-bah-benchmark"]) — not by symbol —
    so a [Map.mem positions symbol] check would never fire and the strategy
    would re-enter on every subsequent day with leftover cash >= one share's
    worth. Walking the values once per call is cheap (the map holds at most one
    entry for a single-symbol strategy). *)
let _has_position_for_symbol ~(positions : Position.t String.Map.t)
    ~(symbol : string) : bool =
  Map.exists positions ~f:(fun (pos : Position.t) ->
      match pos.state with
      | Position.Entering _ | Position.Holding _ | Position.Exiting _ ->
          String.equal pos.symbol symbol
      | Position.Closed _ -> false)

(** Single-symbol entry decision. Returns [None] when:
    - the position already exists in [positions] (don't double-enter), or
    - no price is available for [symbol] today (skip until data arrives), or
    - the available cash can't buy at least one share. *)
let _maybe_enter ~(symbol : string)
    ~(get_price : Strategy_interface.get_price_fn) ~(cash : float)
    ~(positions : Position.t String.Map.t) : Position.transition option =
  if _has_position_for_symbol ~positions ~symbol then None
  else
    match get_price symbol with
    | None -> None
    | Some price -> _entry_from_price price ~symbol ~cash

let _on_market_close (config : config) ~get_price ~get_indicator:_
    ~(portfolio : Portfolio_view.t) =
  let transitions =
    match
      _maybe_enter ~symbol:config.symbol ~get_price ~cash:portfolio.cash
        ~positions:portfolio.positions
    with
    | None -> []
    | Some t -> [ t ]
  in
  Result.return { Strategy_interface.transitions }

let make (config : config) : (module Strategy_interface.STRATEGY) =
  let module M = struct
    let on_market_close = _on_market_close config
    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
