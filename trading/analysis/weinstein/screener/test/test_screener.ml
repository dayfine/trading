open OUnit2
open Core
open Matchers
open Screener
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"

let make_bar ?(volume = 1000) date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.02;
    low_price = adjusted_close *. 0.98;
    close_price = adjusted_close;
    adjusted_close;
    volume;
  }

let weekly_bars_with_volumes prices_and_volumes =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices_and_volumes ~f:(fun i (p, v) ->
      make_bar ~volume:v (Date.to_string (Date.add_days base (i * 7))) p)

let weekly_bars prices =
  weekly_bars_with_volumes (List.map prices ~f:(fun p -> (p, 1000)))

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

(** Rising bars with a volume spike at [spike_idx]: spike volume 3000, rest
    1000. *)
let rising_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> weekly_bars_with_volumes

(** Make a Stock_analysis.t for a given ticker with controlled stage. *)
let make_analysis ticker prior bars =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker ~bars
    ~benchmark_bars:[] ~prior_stage:prior ~as_of_date:as_of

(** Build a sector context. *)
let make_sector ?(rating = (Neutral : sector_rating)) name =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

(** Build an empty sector map. *)
let empty_sector_map () = Hashtbl.create (module String)

(** Build a sector map with entries. *)
let sector_map_of entries =
  let m = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (ticker, sector) ->
      Hashtbl.set m ~key:ticker ~data:sector);
  m

(* ------------------------------------------------------------------ *)
(* Macro gate: Bearish → no buys                                       *)
(* ------------------------------------------------------------------ *)

let test_bearish_macro_no_buys _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

let test_bullish_macro_no_shorts _ =
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let decline2 = List.init 20 ~f:(fun i -> 85.0 -. (Float.of_int i *. 1.5)) in
  let bars = declining @ flat @ decline2 |> weekly_bars in
  let stocks =
    [ make_analysis "XYZ" (Some (Stage3 { weeks_topping = 8 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Sector gate: weak sector excluded from buys                         *)
(* ------------------------------------------------------------------ *)

let test_weak_sector_excluded_from_buys _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let sector_map =
    sector_map_of [ ("AAPL", make_sector ~rating:Weak "Tech") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty

let test_strong_sector_excluded_from_shorts _ =
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let decline2 = List.init 20 ~f:(fun i -> 85.0 -. (Float.of_int i *. 1.5)) in
  let bars = declining @ flat @ decline2 |> weekly_bars in
  let stocks =
    [ make_analysis "XYZ" (Some (Stage3 { weeks_topping = 8 })) bars ]
  in
  let sector_map =
    sector_map_of [ ("XYZ", make_sector ~rating:Strong "Energy") ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result.short_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Held tickers excluded                                               *)
(* ------------------------------------------------------------------ *)

let test_held_tickers_excluded _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[ "AAPL" ]
  in
  assert_that result.buy_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Macro trend propagated                                              *)
(* ------------------------------------------------------------------ *)

let test_macro_trend_propagated _ =
  let result =
    screen ~config:cfg ~macro_trend:Bearish ~sector_map:(empty_sector_map ())
      ~stocks:[] ~held_tickers:[]
  in
  assert_that result.macro_trend (equal_to Bearish)

let test_macro_trend_neutral _ =
  let result =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks:[] ~held_tickers:[]
  in
  assert_that result.macro_trend (equal_to Neutral)

(* ------------------------------------------------------------------ *)
(* Candidate fields                                                     *)
(* ------------------------------------------------------------------ *)

let test_candidate_has_suggested_entry _ =
  (* spike_idx = n-4 = 31: inside default 8-bar lookback, 4 baseline bars
     before it → ratio = 3.0 → Strong volume → is_breakout_candidate = true *)
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let stocks =
    [ make_analysis "MSFT" (Some (Stage1 { weeks_in_base = 10 })) bars ]
  in
  let result =
    screen ~config:cfg ~macro_trend:Bullish ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  match result.buy_candidates with
  | [] -> assert_failure "Expected at least one buy candidate"
  | c :: _ ->
      assert_bool "entry > 0" Float.(c.suggested_entry > 0.0);
      assert_bool "stop < entry" Float.(c.suggested_stop < c.suggested_entry);
      assert_bool "risk_pct > 0" Float.(c.risk_pct > 0.0)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let stocks =
    [ make_analysis "AAPL" (Some (Stage1 { weeks_in_base = 12 })) bars ]
  in
  let r1 =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  let r2 =
    screen ~config:cfg ~macro_trend:Neutral ~sector_map:(empty_sector_map ())
      ~stocks ~held_tickers:[]
  in
  assert_that
    (List.length r1.buy_candidates)
    (equal_to (List.length r2.buy_candidates));
  assert_that
    (List.length r1.short_candidates)
    (equal_to (List.length r2.short_candidates))

let suite =
  "screener_tests"
  >::: [
         "test_bearish_macro_no_buys" >:: test_bearish_macro_no_buys;
         "test_bullish_macro_no_shorts" >:: test_bullish_macro_no_shorts;
         "test_weak_sector_excluded_from_buys"
         >:: test_weak_sector_excluded_from_buys;
         "test_strong_sector_excluded_from_shorts"
         >:: test_strong_sector_excluded_from_shorts;
         "test_held_tickers_excluded" >:: test_held_tickers_excluded;
         "test_macro_trend_propagated" >:: test_macro_trend_propagated;
         "test_macro_trend_neutral" >:: test_macro_trend_neutral;
         "test_candidate_has_suggested_entry"
         >:: test_candidate_has_suggested_entry;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
       ]

let () = run_test_tt_main suite
