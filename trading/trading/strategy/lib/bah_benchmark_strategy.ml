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

(** All-cash sizing: convert available cash to whole shares at [close_price].
    Returns [None] when the cash can't buy a single share (price exceeds cash)
    or when inputs are non-positive — both cases should not emit a transition.
*)
let _shares_from_cash ~(cash : float) ~(close_price : float) : float option =
  if not (_valid_sizing_inputs ~cash ~close_price) then None
  else
    let shares = Float.round_down (cash /. close_price) in
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

(** True if any value in [positions] points at [symbol]. The simulator keys its
    position map by [position_id] (e.g. ["SPY-bah-benchmark"]) — not by symbol —
    so a [Map.mem positions symbol] check would never fire and the strategy
    would re-enter on every subsequent day with leftover cash >= one share's
    worth. Walking the values once per call is cheap (the map holds at most one
    entry for a single-symbol strategy). *)
let _has_position_for_symbol ~(positions : Position.t String.Map.t)
    ~(symbol : string) : bool =
  Map.exists positions ~f:(fun (pos : Position.t) ->
      String.equal pos.symbol symbol)

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
