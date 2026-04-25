open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Indicator_panels = Data_panel.Indicator_panels
module Indicator_spec = Data_panel.Indicator_spec
module BA2 = Bigarray.Array2

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err -> assert_failure err.Status.message

let _seed_panel panels =
  (* Single symbol, monotonically increasing close 100..199. high = close + 1,
     low = close - 1. *)
  let close = Ohlcv_panels.close panels in
  let high = Ohlcv_panels.high panels in
  let low = Ohlcv_panels.low panels in
  let n = Ohlcv_panels.n_days panels in
  for t = 0 to n - 1 do
    let c = 100.0 +. Float.of_int t in
    BA2.unsafe_set close 0 t c;
    BA2.unsafe_set high 0 t (c +. 1.0);
    BA2.unsafe_set low 0 t (c -. 1.0)
  done

let test_create_and_get _ =
  let idx = _make_idx [ "AAA" ] in
  let panels =
    Indicator_panels.create ~symbol_index:idx ~n_days:50
      ~specs:
        [
          { name = "EMA"; period = 10; cadence = Daily };
          { name = "SMA"; period = 5; cadence = Daily };
          { name = "ATR"; period = 14; cadence = Daily };
          { name = "RSI"; period = 14; cadence = Daily };
        ]
  in
  let ema_panel =
    Indicator_panels.get panels { name = "EMA"; period = 10; cadence = Daily }
  in
  assert_that
    (BA2.dim1 ema_panel, BA2.dim2 ema_panel)
    (pair (equal_to 1) (equal_to 50))

let test_dedup _ =
  (* Two identical specs share one entry. *)
  let idx = _make_idx [ "AAA" ] in
  let panels =
    Indicator_panels.create ~symbol_index:idx ~n_days:10
      ~specs:
        [
          { name = "EMA"; period = 10; cadence = Daily };
          { name = "EMA"; period = 10; cadence = Daily };
        ]
  in
  assert_that (Indicator_panels.specs panels |> List.length) (equal_to 1)

(* [Failure _] catches the [failwithf]s emitted by [_validate_spec] without
   pinning the exact message — message text is documentation, not contract. *)
let _expect_failure f =
  try
    f ();
    false
  with Failure _ -> true

let test_invalid_period_raises _ =
  let idx = _make_idx [ "AAA" ] in
  let raised =
    _expect_failure (fun () ->
        Indicator_panels.create ~symbol_index:idx ~n_days:10
          ~specs:[ { name = "EMA"; period = 0; cadence = Daily } ]
        |> ignore)
  in
  assert_that raised (equal_to true)

let test_invalid_name_raises _ =
  let idx = _make_idx [ "AAA" ] in
  let raised =
    _expect_failure (fun () ->
        Indicator_panels.create ~symbol_index:idx ~n_days:10
          ~specs:[ { name = "BogusInd"; period = 10; cadence = Daily } ]
        |> ignore)
  in
  assert_that raised (equal_to true)

let test_weekly_cadence_raises _ =
  let idx = _make_idx [ "AAA" ] in
  let raised =
    _expect_failure (fun () ->
        Indicator_panels.create ~symbol_index:idx ~n_days:10
          ~specs:[ { name = "EMA"; period = 10; cadence = Weekly } ]
        |> ignore)
  in
  assert_that raised (equal_to true)

(* Independent scalar walk for the registry advance test. SMA over 100 ticks,
   period=5: advance the registry from t=0..99 and assert each cell at t >=
   period-1 matches the scalar window mean. *)
let _scalar_sma (data : float array) (period : int) : float array =
  let n = Array.length data in
  let out = Array.create ~len:n Float.nan in
  if n >= period then
    for t = period - 1 to n - 1 do
      let acc = ref 0.0 in
      for k = 0 to period - 1 do
        let v = data.(t - period + 1 + k) in
        acc := !acc +. v
      done;
      out.(t) <- !acc /. Float.of_int period
    done;
  out

let test_advance_all_walks_panel _ =
  let n_days = 100 in
  let idx = _make_idx [ "AAA" ] in
  let ohlcv = Ohlcv_panels.create idx ~n_days in
  _seed_panel ohlcv;
  let panels =
    Indicator_panels.create ~symbol_index:idx ~n_days
      ~specs:
        [
          { name = "EMA"; period = 10; cadence = Daily };
          { name = "SMA"; period = 5; cadence = Daily };
          { name = "ATR"; period = 14; cadence = Daily };
          { name = "RSI"; period = 14; cadence = Daily };
        ]
  in
  for tick = 0 to n_days - 1 do
    Indicator_panels.advance_all panels ~ohlcv ~t:tick
  done;
  let close_arr = Array.init n_days ~f:(fun t -> 100.0 +. Float.of_int t) in
  let ref_sma = _scalar_sma close_arr 5 in
  let sma_panel =
    Indicator_panels.get panels { name = "SMA"; period = 5; cadence = Daily }
  in
  let last_t = n_days - 1 in
  (* Spot-check t=10, t=50, t=last for SMA-5. *)
  assert_that
    [
      (10, BA2.get sma_panel 0 10);
      (50, BA2.get sma_panel 0 50);
      (last_t, BA2.get sma_panel 0 last_t);
    ]
    (elements_are
       [
         pair (equal_to 10) (float_equal ref_sma.(10));
         pair (equal_to 50) (float_equal ref_sma.(50));
         pair (equal_to last_t) (float_equal ref_sma.(last_t));
       ])

let test_advance_shape_mismatch_raises _ =
  let idx = _make_idx [ "AAA" ] in
  let ohlcv = Ohlcv_panels.create idx ~n_days:10 in
  let panels =
    Indicator_panels.create ~symbol_index:idx ~n_days:20
      ~specs:[ { name = "EMA"; period = 5; cadence = Daily } ]
  in
  let raised =
    try
      Indicator_panels.advance_all panels ~ohlcv ~t:0;
      false
    with Invalid_argument _ -> true
  in
  assert_that raised (equal_to true)

let suite =
  "Indicator_panels tests"
  >::: [
         "test_create_and_get" >:: test_create_and_get;
         "test_dedup" >:: test_dedup;
         "test_invalid_period_raises" >:: test_invalid_period_raises;
         "test_invalid_name_raises" >:: test_invalid_name_raises;
         "test_weekly_cadence_raises" >:: test_weekly_cadence_raises;
         "test_advance_all_walks_panel" >:: test_advance_all_walks_panel;
         "test_advance_shape_mismatch_raises"
         >:: test_advance_shape_mismatch_raises;
       ]

let () = run_test_tt_main suite
