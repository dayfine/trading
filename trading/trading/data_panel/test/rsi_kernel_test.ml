open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Rsi_kernel = Data_panel.Rsi_kernel
module BA2 = Bigarray.Array2

(* Scalar reference Wilder RSI with the same expression form as the kernel. *)
let _scalar_rsi (close : float array) (period : int) : float array =
  let n = Array.length close in
  let out = Array.create ~len:n Float.nan in
  if n <= period then out
  else begin
    let avg_g = ref 0.0 in
    let avg_l = ref 0.0 in
    let acc_g = ref 0.0 in
    let acc_l = ref 0.0 in
    for k = 1 to period do
      let c = close.(k) in
      let pc = close.(k - 1) in
      let diff = c -. pc in
      let g = if Float.( > ) diff 0.0 then diff else 0.0 in
      let l = if Float.( < ) diff 0.0 then -.diff else 0.0 in
      acc_g := !acc_g +. g;
      acc_l := !acc_l +. l
    done;
    let period_f = Float.of_int period in
    avg_g := !acc_g /. period_f;
    avg_l := !acc_l /. period_f;
    let rsi_of g l =
      if Float.is_nan g || Float.is_nan l then Float.nan
      else if Float.equal l 0.0 then 100.0
      else 100.0 -. (100.0 /. (1.0 +. (g /. l)))
    in
    out.(period) <- rsi_of !avg_g !avg_l;
    let pm1 = Float.of_int (period - 1) in
    for t = period + 1 to n - 1 do
      let c = close.(t) in
      let pc = close.(t - 1) in
      let diff = c -. pc in
      let g = if Float.( > ) diff 0.0 then diff else 0.0 in
      let l = if Float.( < ) diff 0.0 then -.diff else 0.0 in
      let prev_g = !avg_g in
      let prev_l = !avg_l in
      avg_g := ((prev_g *. pm1) +. g) /. period_f;
      avg_l := ((prev_l *. pm1) +. l) /. period_f;
      out.(t) <- rsi_of !avg_g !avg_l
    done;
    out
  end

let _random_walk ~seed ~n ~start ~step_max : float array =
  let state = ref (Int64.of_int seed) in
  let next_uniform () =
    let next =
      Int64.bit_and
        (Int64.( + ) (Int64.( * ) !state 1664525L) 1013904223L)
        0xFFFFFFFFL
    in
    state := next;
    let v = Int64.to_int_exn next in
    Float.of_int v /. 4294967296.0
  in
  let arr = Array.create ~len:n 0.0 in
  arr.(0) <- start;
  for i = 1 to n - 1 do
    let u = next_uniform () in
    let step = ((u *. 2.0) -. 1.0) *. step_max in
    arr.(i) <- arr.(i - 1) +. step
  done;
  arr

let _build_panel ~n_symbols ~n_days =
  let universe = List.init n_symbols ~f:(fun i -> Printf.sprintf "S%04d" i) in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> assert_failure err.Status.message
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let close = Ohlcv_panels.close panels in
  let series = Array.create ~len:n_symbols [||] in
  for r = 0 to n_symbols - 1 do
    let walk =
      _random_walk ~seed:(42 + r) ~n:n_days
        ~start:(100.0 +. Float.of_int r)
        ~step_max:1.5
    in
    series.(r) <- walk;
    for t = 0 to n_days - 1 do
      BA2.unsafe_set close r t walk.(t)
    done
  done;
  (panels, series)

let _make_output ~n_symbols ~n_days =
  let p = BA2.create Bigarray.Float64 Bigarray.C_layout n_symbols n_days in
  BA2.fill p Float.nan;
  p

let _ulp_distance a b =
  if Float.is_nan a && Float.is_nan b then 0
  else if Float.equal a b then 0
  else
    let ai = Int64.bits_of_float a in
    let bi = Int64.bits_of_float b in
    let diff = Int64.abs (Int64.( - ) ai bi) in
    Int64.to_int_exn diff

let _max_ulp_drift kernel_panel reference n_symbols n_days period =
  let max_ulp = ref 0 in
  let max_abs = ref 0.0 in
  for r = 0 to n_symbols - 1 do
    for t = period to n_days - 1 do
      let k_v = BA2.unsafe_get kernel_panel r t in
      let r_v = reference.(r).(t) in
      let ulp = _ulp_distance k_v r_v in
      if ulp > !max_ulp then max_ulp := ulp;
      let abs_diff = Float.abs (k_v -. r_v) in
      if Float.( > ) abs_diff !max_abs then max_abs := abs_diff
    done
  done;
  (!max_ulp, !max_abs)

let test_warmup_writes_nan _ =
  let panels, _ = _build_panel ~n_symbols:1 ~n_days:20 in
  let close = Ohlcv_panels.close panels in
  let avg_gain = _make_output ~n_symbols:1 ~n_days:20 in
  let avg_loss = _make_output ~n_symbols:1 ~n_days:20 in
  let output = _make_output ~n_symbols:1 ~n_days:20 in
  for t = 0 to 13 do
    Rsi_kernel.advance ~close ~avg_gain ~avg_loss ~output ~period:14 ~t
  done;
  assert_that
    (List.init 14 ~f:(fun t -> Float.is_nan (BA2.get output 0 t)))
    (equal_to (List.init 14 ~f:(fun _ -> true)))

let test_no_loss_yields_100 _ =
  (* Strictly monotonic close: every diff > 0, so loss always 0. RSI = 100 at
     every cell from t=period onward. *)
  let n_days = 20 in
  let universe = [ "AAA" ] in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> assert_failure err.Status.message
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let close = Ohlcv_panels.close panels in
  for t = 0 to n_days - 1 do
    BA2.unsafe_set close 0 t (100.0 +. Float.of_int t)
  done;
  let avg_gain = _make_output ~n_symbols:1 ~n_days in
  let avg_loss = _make_output ~n_symbols:1 ~n_days in
  let output = _make_output ~n_symbols:1 ~n_days in
  for t = 0 to n_days - 1 do
    Rsi_kernel.advance ~close ~avg_gain ~avg_loss ~output ~period:14 ~t
  done;
  assert_that
    (List.init 6 ~f:(fun i -> BA2.get output 0 (14 + i)))
    (elements_are
       [
         float_equal 100.0;
         float_equal 100.0;
         float_equal 100.0;
         float_equal 100.0;
         float_equal 100.0;
         float_equal 100.0;
       ])

let test_parity_vs_scalar_reference _ =
  let n_symbols = 50 in
  let n_days = 252 in
  let period = 14 in
  let panels, series = _build_panel ~n_symbols ~n_days in
  let close = Ohlcv_panels.close panels in
  let avg_gain = _make_output ~n_symbols ~n_days in
  let avg_loss = _make_output ~n_symbols ~n_days in
  let output = _make_output ~n_symbols ~n_days in
  for t = 0 to n_days - 1 do
    Rsi_kernel.advance ~close ~avg_gain ~avg_loss ~output ~period ~t
  done;
  let reference = Array.map series ~f:(fun walk -> _scalar_rsi walk period) in
  let max_ulp, max_abs =
    _max_ulp_drift output reference n_symbols n_days period
  in
  let msg =
    Printf.sprintf "max_ulp = %d, max abs diff = %.3e" max_ulp max_abs
  in
  assert_that max_ulp (equal_to ~msg 0);
  assert_that max_abs (le (module Float_ord) 1e-9)

let suite =
  "Rsi_kernel tests"
  >::: [
         "test_warmup_writes_nan" >:: test_warmup_writes_nan;
         "test_no_loss_yields_100" >:: test_no_loss_yields_100;
         "test_parity_vs_scalar_reference" >:: test_parity_vs_scalar_reference;
       ]

let () = run_test_tt_main suite
