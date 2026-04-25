open Core
open Trading_strategy
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Indicator_panels = Data_panel.Indicator_panels
module Get_indicator_adapter = Data_panel.Get_indicator_adapter

type config = {
  ohlcv : Ohlcv_panels.t;
  indicators : Indicator_panels.t;
  calendar : Date.t array;
  primary_index : string;
  universe : string list;
}

(* Date -> column lookup. The same calendar drives [Ohlcv_panels.load_from_csv_calendar] and the
   per-tick advance, so the date set is identical. Hashtbl keyed on Date.t for O(1) lookup. *)
let _calendar_index calendar =
  let tbl = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add tbl ~key:d ~data:i |> (ignore : [ `Ok | `Duplicate ] -> unit));
  tbl

(* Today's date is read from the primary index bar — same heuristic as
   [Tiered_strategy_wrapper._current_date]. When the benchmark bar is missing
   we cannot resolve a panel column, so the caller falls back to the
   simulator's original [get_indicator]. *)
let _today_date_opt ~(get_price : Strategy_interface.get_price_fn)
    ~primary_index =
  Option.map (get_price primary_index) ~f:(fun bar ->
      bar.Types.Daily_price.date)

let _write_symbol_bar ~ohlcv ~symbol_index ~get_price ~day sym =
  match Symbol_index.to_row symbol_index sym with
  | None -> () (* symbol not in panel universe — skip *)
  | Some row -> (
      match get_price sym with
      | None -> ()
      | Some bar -> Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day bar)

let _write_today_bars ~ohlcv ~symbol_index ~get_price ~universe ~day =
  List.iter universe ~f:(_write_symbol_bar ~ohlcv ~symbol_index ~get_price ~day)

let _advance_panels_and_run ~(config : config)
    ~(module_ : (module Strategy_interface.STRATEGY)) ~get_price ~portfolio ~day
    =
  let (module S) = module_ in
  let symbol_index = Ohlcv_panels.symbol_index config.ohlcv in
  _write_today_bars ~ohlcv:config.ohlcv ~symbol_index ~get_price
    ~universe:config.universe ~day;
  Indicator_panels.advance_all config.indicators ~ohlcv:config.ohlcv ~t:day;
  let get_indicator = Get_indicator_adapter.make config.indicators ~t:day in
  S.on_market_close ~get_price ~get_indicator ~portfolio

let _on_market_close ~(config : config)
    ~(inner_module : (module Strategy_interface.STRATEGY)) ~get_price
    ~get_indicator ~portfolio =
  let (module S) = inner_module in
  let calendar_idx = _calendar_index config.calendar in
  let today = _today_date_opt ~get_price ~primary_index:config.primary_index in
  let day_opt = Option.bind today ~f:(Hashtbl.find calendar_idx) in
  match day_opt with
  | None ->
      (* No primary-index bar today, or date out of calendar — pass through. *)
      S.on_market_close ~get_price ~get_indicator ~portfolio
  | Some day ->
      _advance_panels_and_run ~config ~module_:inner_module ~get_price
        ~portfolio ~day

let wrap ~config (module S : Strategy_interface.STRATEGY) =
  let inner_module = (module S : Strategy_interface.STRATEGY) in
  let module Wrapped = struct
    let name = S.name

    let on_market_close ~get_price ~get_indicator ~portfolio =
      _on_market_close ~config ~inner_module ~get_price ~get_indicator
        ~portfolio
  end in
  (module Wrapped : Strategy_interface.STRATEGY)
