open Core

(* CSV-backed mode wraps a [Price_cache] + [Indicator_manager]; callback mode
   wraps a pair of caller-supplied price closures. The two backends are kept as
   distinct constructors so the per-call path is a single match without any
   per-symbol allocation overhead. *)
type backend =
  | Csv of {
      price_cache : Price_cache.t;
      indicator_manager : Indicator_manager.t;
    }
  | Callbacks of {
      get_price : symbol:string -> date:Date.t -> Types.Daily_price.t option;
      get_previous_bar :
        symbol:string -> date:Date.t -> Types.Daily_price.t option;
    }

type t = { backend : backend }

let create ~data_dir =
  let price_cache = Price_cache.create ~data_dir in
  let indicator_manager = Indicator_manager.create ~price_cache in
  { backend = Csv { price_cache; indicator_manager } }

let create_with_callbacks ~get_price ~get_previous_bar =
  { backend = Callbacks { get_price; get_previous_bar } }

(* A bar is "valid" only if it has a positive close price. Delisted symbols in
   some bar datasets (e.g. EODHD) emit zero-OHLC rows after the delisting date
   instead of truncating the file. Returning such a bar from [get_price] would
   propagate the zero through engine.update_market → fill exit at price=0 →
   Position.apply_transition error "exit_price must be positive: 0.00". MON
   (Monsanto, delisted 2018) hit this on 2023-01-11 in the sp500-historical
   universe. Treating zero-close bars as "no bar today" is consistent with the
   delisting reality and lets the existing Stale_hold detector report the
   stuck position. *)
let _is_valid_bar (bar : Types.Daily_price.t) = Float.(bar.close_price > 0.0)

let _filter_valid = function
  | Some bar when _is_valid_bar bar -> Some bar
  | Some _ | None -> None

let get_price t ~symbol ~date =
  (* Direct date-indexed lookup in CSV mode. The previous implementation went
     through [get_prices ~end_date:date] which allocates a fresh [List.filter]'d
     copy of the full price history per call, then walks it again with
     [List.find]. For a per-tick simulation loop (many [get_price] calls per
     (symbol, day) cell at universe-scale per memtrace), that compounded into
     billions of cons-cell allocations per run. [Price_cache.get_price_on_date]
     is O(1) after first symbol load, with no per-call allocation. *)
  let raw =
    match t.backend with
    | Csv { price_cache; _ } ->
        Price_cache.get_price_on_date price_cache ~symbol ~date
    | Callbacks { get_price; _ } -> get_price ~symbol ~date
  in
  _filter_valid raw

let get_previous_bar t ~symbol ~date =
  let raw =
    match t.backend with
    | Csv { price_cache; _ } ->
        Price_cache.get_previous_bar price_cache ~symbol ~date
    | Callbacks { get_previous_bar; _ } -> get_previous_bar ~symbol ~date
  in
  _filter_valid raw

let get_indicator t ~symbol ~indicator_name ~period ~cadence ~date =
  match t.backend with
  | Csv { indicator_manager; _ } -> (
      let spec = Indicator_manager.{ name = indicator_name; period; cadence } in
      match
        Indicator_manager.get_indicator indicator_manager ~symbol ~spec ~date
      with
      | Error _ -> None
      | Ok value -> value)
  | Callbacks _ ->
      (* Callback mode: indicators are not served through the adapter. The
         Weinstein strategy ignores [get_indicator] entirely, so this surface
         is never exercised in callback mode. *)
      None

let finalize_period t ~cadence ~end_date =
  match t.backend with
  | Csv { indicator_manager; _ } ->
      Indicator_manager.finalize_period indicator_manager ~cadence ~end_date
  | Callbacks _ ->
      (* Callback mode: indicator manager has no provisional state to
         invalidate; this is a no-op. Documented in the .mli. *)
      ()
