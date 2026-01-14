(** Indicator computer implementation *)

open Core

type indicator_result = {
  symbol : string;
  indicator_values : Indicator_types.indicator_value list;
}

let _prices_to_indicator_values (prices : Types.Daily_price.t list) :
    Indicator_types.indicator_value list =
  List.map prices ~f:(fun (price : Types.Daily_price.t) ->
      { Indicator_types.date = price.date; value = price.close_price })

let compute_ema ~symbol ~prices ~period ~cadence ?as_of_date () =
  (* Validate inputs *)
  if period <= 0 then
    Error (Status.invalid_argument_error "Period must be positive")
  else if List.is_empty prices then
    Error (Status.invalid_argument_error "Prices list cannot be empty")
  else
    (* Convert to desired cadence *)
    let converted_prices =
      Time_series.convert_cadence prices ~cadence ~as_of_date
    in
    if List.is_empty converted_prices then
      Error
        (Status.invalid_argument_error
           "No prices available after cadence conversion")
    else
      (* Extract close prices as indicator values *)
      let indicator_values = _prices_to_indicator_values converted_prices in
      (* Compute EMA *)
      let ema_values = Ema.calculate_ema indicator_values period in
      (* Return result *)
      Ok { symbol; indicator_values = ema_values }
