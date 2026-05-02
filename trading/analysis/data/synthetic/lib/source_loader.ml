open Core

(* SPY-shape parameters for the synthetic source. Calibrated rough-eye to
   SPY 1993–2025: ~8% annualised drift, ~19% annualised vol. The bootstrap
   tests don't depend on these exact values; they only require the source
   has well-defined finite moments so we can compare them to the synth. *)
let _drift_per_day = 0.0003
let _vol_per_day = 0.012
let _start_price = 100.0
let _constant_volume = 10_000_000

(* Box-Muller transform: turn two U(0,1) samples into one N(0,1) sample.
   We discard the second normal — fine for fixture data, marginally less
   efficient but simpler. *)
let _normal_sample rng =
  let u1 = Stdlib.Random.State.float rng 1.0 in
  let u2 = Stdlib.Random.State.float rng 1.0 in
  (* Avoid log(0). *)
  let u1' = Float.max u1 Float.min_positive_normal_value in
  Float.sqrt (-2.0 *. Float.log u1') *. Float.cos (2.0 *. Float.pi *. u2)

let _next_business_day d =
  let next = Date.add_days d 1 in
  match Date.day_of_week next with
  | Sat -> Date.add_days next 2
  | Sun -> Date.add_days next 1
  | _ -> next

let _normalise_start_date d =
  match Date.day_of_week d with
  | Sat -> Date.add_days d 2
  | Sun -> Date.add_days d 1
  | _ -> d

(* Build a single bar from a close price and a date. We synthesise OHLC from
   close ± a small fraction so the bar is well-formed; the bootstrap doesn't
   care about intra-day structure for our statistical tests. *)
let _build_bar ~date ~close : Types.Daily_price.t =
  let high = close *. 1.005 in
  let low = close *. 0.995 in
  let open_price = close *. 0.999 in
  {
    date;
    open_price;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = _constant_volume;
  }

let synthetic_spy_like ~start_date ~n_days ~seed =
  let rng = Stdlib.Random.State.make [| seed |] in
  let start = _normalise_start_date start_date in
  let rec loop acc date price remaining =
    if remaining = 0 then List.rev acc
    else
      let bar = _build_bar ~date ~close:price in
      let z = _normal_sample rng in
      let next_price =
        price *. Float.exp (_drift_per_day +. (_vol_per_day *. z))
      in
      loop (bar :: acc) (_next_business_day date) next_price (remaining - 1)
  in
  loop [] start _start_price n_days

let load_csv ~path =
  match Sys_unix.file_exists path with
  | `No | `Unknown ->
      Status.error_not_found (Printf.sprintf "source CSV not found: %s" path)
  | `Yes -> (
      let lines = In_channel.with_file path ~f:In_channel.input_lines in
      match Csv.Parser.parse_lines lines with
      | Ok bars -> Ok bars
      | Error e -> Error e)
