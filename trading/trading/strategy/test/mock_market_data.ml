(** Mock market data implementation for testing strategies *)

open Core

type t = {
  symbol_data : (string, Types.Daily_price.t list) Hashtbl.t;
  ema_cache : (string * int, (Date.t * float) list) Hashtbl.t;
  current_date : Date.t;
}
(** Price data with indicators *)

(** Compute EMA from price data *)
let compute_ema prices period =
  if List.is_empty prices || period <= 0 then []
  else
    let multiplier = 2.0 /. Float.of_int (period + 1) in
    let rec compute acc remaining =
      match remaining with
      | [] -> List.rev acc
      | price :: rest -> (
          match acc with
          | [] ->
              (* First EMA = close price *)
              compute [ (price.Types.Daily_price.date, price.close_price) ] rest
          | (_, prev_ema) :: _ ->
              (* EMA = (close - prev_ema) * multiplier + prev_ema *)
              let new_ema =
                ((price.close_price -. prev_ema) *. multiplier) +. prev_ema
              in
              compute ((price.date, new_ema) :: acc) rest)
    in
    compute [] prices

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

(** Get price history up to current date *)
let get_price_history t symbol ?lookback_days () =
  match Hashtbl.find t.symbol_data symbol with
  | None -> []
  | Some prices -> (
      let up_to_current =
        List.filter prices ~f:(fun (p : Types.Daily_price.t) ->
            Date.(p.date <= t.current_date))
      in
      match lookback_days with
      | None -> up_to_current
      | Some days ->
          let start_date = Date.add_days t.current_date (-(days - 1)) in
          List.filter up_to_current ~f:(fun (p : Types.Daily_price.t) ->
              Date.(p.date >= start_date)))

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
  | Some ema_series -> (
      let up_to_current =
        List.filter ema_series ~f:(fun (date, _) ->
            Date.(date <= t.current_date))
      in
      match lookback_days with
      | None -> List.map up_to_current ~f:(fun (date, value) -> (date, value))
      | Some days ->
          let start_date = Date.add_days t.current_date (-(days - 1)) in
          List.filter up_to_current ~f:(fun (date, _) ->
              Date.(date >= start_date))
          |> List.map ~f:(fun (date, value) -> (date, value)))

(** Get indicator value at current date (generic interface) *)
let get_indicator t symbol indicator_name period =
  match indicator_name with
  | "EMA" -> get_ema t symbol period
  | _ -> None  (* Only EMA supported for now *)
