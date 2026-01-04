(** Price sequence generators for testing *)

open Core

type trend =
  | Uptrend of float  (** Percent increase per day *)
  | Downtrend of float  (** Percent decrease per day *)
  | Sideways

(** Generate a sequence of daily prices *)
let make_price_sequence ~symbol:_ ~start_date ~days ~base_price ~trend
    ~volatility =
  let rec generate acc date remaining_days current_price =
    if remaining_days <= 0 then List.rev acc
    else
      (* Apply trend *)
      let trend_price =
        match trend with
        | Uptrend pct -> current_price *. (1.0 +. (pct /. 100.0))
        | Downtrend pct -> current_price *. (1.0 -. (pct /. 100.0))
        | Sideways -> current_price
      in
      (* Add some noise for OHLC *)
      let noise = Random.float volatility in
      let open_price = trend_price *. (1.0 -. (noise /. 2.0)) in
      let close_price = trend_price *. (1.0 +. (noise /. 2.0)) in
      let high_price = Float.max open_price close_price *. (1.0 +. noise) in
      let low_price = Float.min open_price close_price *. (1.0 -. noise) in
      let daily_price =
        Types.Daily_price.
          {
            date;
            open_price;
            high_price;
            low_price;
            close_price;
            volume = 1000000;
            adjusted_close = close_price;
          }
      in
      generate (daily_price :: acc) (Date.add_days date 1) (remaining_days - 1)
        close_price
  in
  Random.init 42;
  (* Fixed seed for reproducibility *)
  generate [] start_date days base_price

(** Create a price spike at a specific date *)
let with_spike prices ~spike_date ~spike_percent =
  List.map prices ~f:(fun (p : Types.Daily_price.t) ->
      if Date.equal p.date spike_date then
        let spike_multiplier = 1.0 +. (spike_percent /. 100.0) in
        {
          p with
          open_price = p.open_price *. spike_multiplier;
          high_price = p.high_price *. spike_multiplier;
          low_price = p.low_price *. spike_multiplier;
          close_price = p.close_price *. spike_multiplier;
        }
      else p)

(** Create a price gap (open significantly different from previous close) *)
let with_gap prices ~gap_date ~gap_percent =
  let rec process acc prev_close = function
    | [] -> List.rev acc
    | (p : Types.Daily_price.t) :: rest ->
        if Date.equal p.date gap_date then
          let gap_multiplier = 1.0 +. (gap_percent /. 100.0) in
          let new_open = prev_close *. gap_multiplier in
          let gap_size = new_open -. p.open_price in
          let gapped_price =
            {
              p with
              open_price = new_open;
              high_price = p.high_price +. gap_size;
              low_price = p.low_price +. gap_size;
              close_price = p.close_price +. gap_size;
            }
          in
          process (gapped_price :: acc) gapped_price.close_price rest
        else process (p :: acc) p.close_price rest
  in
  match prices with
  | [] -> []
  | first :: rest -> process [ first ] first.close_price rest

(** Create a reversal pattern - trend changes at specific date *)
let with_reversal prices ~reversal_date ~new_trend =
  let before_reversal, after_reversal =
    List.split_while prices ~f:(fun (p : Types.Daily_price.t) ->
        Date.(p.date < reversal_date))
  in
  match after_reversal with
  | [] -> prices
  | first :: _ ->
      let after_prices =
        make_price_sequence ~symbol:"" ~start_date:reversal_date
          ~days:(List.length after_reversal)
          ~base_price:first.close_price ~trend:new_trend ~volatility:0.02
      in
      before_reversal @ after_prices
