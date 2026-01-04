(** Mock market data implementation for testing strategies *)

open Core

type t = {
  symbol_data : (string, Types.Daily_price.t list) Hashtbl.t;
  ema_cache : (string * int, (Date.t * float) list) Hashtbl.t;
  current_date : Date.t;
}
(** Price data with indicators *)

(** Convert price data to indicator values *)
let prices_to_indicator_values (prices : Types.Daily_price.t list) :
    Indicator_types.indicator_value list =
  List.map prices ~f:(fun p ->
      { Indicator_types.date = p.date; value = p.close_price })

(** Compute EMA from price data using real EMA implementation *)
let compute_ema prices period =
  if List.is_empty prices || period <= 0 then []
  else
    let indicator_values = prices_to_indicator_values prices in
    let ema_results = Ema.calculate_ema indicator_values period in
    List.map ema_results ~f:(fun iv -> (iv.date, iv.value))

(** Create mock market data from price lists *)
let create ~data ~ema_periods ~current_date =
  let symbol_data = Hashtbl.create (module String) in
  let ema_cache =
    Hashtbl.Poly.create ~size:(List.length data * List.length ema_periods) ()
  in

  (* Load price data *)
  Hashtbl.iteri symbol_data ~f:(fun ~key:_ ~data:_ -> ());
  List.iter data ~f:(fun (symbol, prices) ->
      Hashtbl.set symbol_data ~key:symbol ~data:prices);

  (* Pre-compute EMAs for all symbols and periods *)
  List.iter data ~f:(fun (symbol, prices) ->
      List.iter ema_periods ~f:(fun period ->
          let ema_values = compute_ema prices period in
          Hashtbl.set ema_cache ~key:(symbol, period) ~data:ema_values));

  { symbol_data; ema_cache; current_date }

(** Advance to a new date *)
let advance t ~date = { t with current_date = date }

(** Get current date *)
let current_date t = t.current_date

(** Get price for symbol at current date *)
let get_price t symbol =
  match Hashtbl.find t.symbol_data symbol with
  | None -> None
  | Some prices ->
      List.find prices ~f:(fun (p : Types.Daily_price.t) ->
          Date.equal p.date t.current_date)

(** Generic helper to filter time series data up to current date with optional
    lookback *)
let filter_time_series ~current_date ~get_date ?lookback_days data =
  let up_to_current =
    List.filter data ~f:(fun item -> Date.(get_date item <= current_date))
  in
  match lookback_days with
  | None -> up_to_current
  | Some days ->
      let start_date = Date.add_days current_date (-(days - 1)) in
      List.filter up_to_current ~f:(fun item ->
          Date.(get_date item >= start_date))

(** Get price history up to current date *)
let get_price_history t symbol ?lookback_days () =
  match Hashtbl.find t.symbol_data symbol with
  | None -> []
  | Some prices ->
      filter_time_series ~current_date:t.current_date
        ~get_date:(fun (p : Types.Daily_price.t) -> p.date)
        ?lookback_days prices

(** Get EMA value at current date *)
let get_ema t symbol period =
  match Hashtbl.find t.ema_cache (symbol, period) with
  | None -> None
  | Some ema_series ->
      List.find ema_series ~f:(fun (date, _) -> Date.equal date t.current_date)
      |> Option.map ~f:snd

(** Get EMA series up to current date *)
let get_ema_series t symbol period ?lookback_days () =
  match Hashtbl.find t.ema_cache (symbol, period) with
  | None -> []
  | Some ema_series ->
      filter_time_series ~current_date:t.current_date ~get_date:fst
        ?lookback_days ema_series

(** Get indicator value at current date (generic interface) *)
let get_indicator t symbol indicator_name period =
  match indicator_name with
  | "EMA" -> get_ema t symbol period
  | _ -> None (* Only EMA supported for now *)
