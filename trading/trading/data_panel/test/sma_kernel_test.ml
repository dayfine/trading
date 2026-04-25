open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Sma_kernel = Data_panel.Sma_kernel
module BA2 = Bigarray.Array2

(* Scalar reference SMA with the same expression form as the kernel: window
   walk uses [acc := !acc +. v] where [v] is bound to a named local before the
   add. Stage 0 lesson: identical expression form is required for
   bit-identical output across Bigarray and float-array storage. *)
let _scalar_sma (data : float array) (period : int) : float array =
  let n = Array.length data in
  let out = Array.create ~len:n Float.nan in
  if n >= period then begin
    let period_f = Float.of_int period in
    for t = period - 1 to n - 1 do
      let acc = ref 0.0 in
      let start_col = t - period + 1 in
      for k = 0 to period - 1 do
        let v = data.(start_col + k) in
        acc := !acc +. v
      done;
      out.(t) <- !acc /. period_f
    done
  end;
  out

(* Same deterministic random walk as ema_kernel_test for parity comparability. *)
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
    | Error err ->
        assert_failure (Printf.sprintf "create failed: %s" err.Status.message)
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
    for t = period - 1 to n_days - 1 do
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
  let panels, _ = _build_panel ~n_symbols:3 ~n_days:10 in
  let input = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols:3 ~n_days:10 in
  Sma_kernel.advance ~input ~output ~period:5 ~t:0;
  Sma_kernel.advance ~input ~output ~period:5 ~t:3;
  assert_that
    [ Float.is_nan (BA2.get output 0 0); Float.is_nan (BA2.get output 1 3) ]
    (equal_to [ true; true ])

let test_canonical_values _ =
  (* Period=3, input [100, 101, 102, 103, 104]: SMA at t=2 is 101.0, t=3 is
     102.0, t=4 is 103.0; t=0 and t=1 are NaN. *)
  let n_days = 5 in
  let universe = [ "AAA" ] in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err ->
        assert_failure (Printf.sprintf "create failed: %s" err.Status.message)
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let close = Ohlcv_panels.close panels in
  Array.iteri [| 100.0; 101.0; 102.0; 103.0; 104.0 |] ~f:(fun i v ->
      BA2.unsafe_set close 0 i v);
  let output = _make_output ~n_symbols:1 ~n_days in
  for t = 0 to n_days - 1 do
    Sma_kernel.advance ~input:close ~output ~period:3 ~t
  done;
  assert_that
    [
      Float.is_nan (BA2.get output 0 0);
      Float.is_nan (BA2.get output 0 1);
      Float.equal (BA2.get output 0 2) 101.0;
      Float.equal (BA2.get output 0 3) 102.0;
      Float.equal (BA2.get output 0 4) 103.0;
    ]
    (equal_to [ true; true; true; true; true ])

let test_parity_vs_scalar_reference _ =
  (* 100-symbol 252-day parity test mirroring ema_kernel_test. *)
  let n_symbols = 100 in
  let n_days = 252 in
  let period = 50 in
  let panels, series = _build_panel ~n_symbols ~n_days in
  let input = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols ~n_days in
  for t = 0 to n_days - 1 do
    Sma_kernel.advance ~input ~output ~period ~t
  done;
  let reference = Array.map series ~f:(fun walk -> _scalar_sma walk period) in
  let max_ulp, max_abs =
    _max_ulp_drift output reference n_symbols n_days period
  in
  let msg =
    Printf.sprintf "max_ulp = %d, max abs diff = %.3e" max_ulp max_abs
  in
  assert_that max_ulp (equal_to ~msg 0);
  assert_that max_abs (le (module Float_ord) 1e-9)

let test_period_one_passthrough _ =
  (* SMA-1 is the identity. *)
  let n_days = 5 in
  let universe = [ "AAA" ] in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err ->
        assert_failure (Printf.sprintf "create failed: %s" err.Status.message)
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let close = Ohlcv_panels.close panels in
  Array.iteri [| 1.0; 2.0; 3.0; 4.0; 5.0 |] ~f:(fun i v ->
      BA2.unsafe_set close 0 i v);
  let output = _make_output ~n_symbols:1 ~n_days in
  for t = 0 to n_days - 1 do
    Sma_kernel.advance ~input:close ~output ~period:1 ~t
  done;
  assert_that
    (List.init n_days ~f:(fun t -> BA2.get output 0 t))
    (elements_are
       [
         float_equal 1.0;
         float_equal 2.0;
         float_equal 3.0;
         float_equal 4.0;
         float_equal 5.0;
       ])

let suite =
  "Sma_kernel tests"
  >::: [
         "test_warmup_writes_nan" >:: test_warmup_writes_nan;
         "test_canonical_values" >:: test_canonical_values;
         "test_parity_vs_scalar_reference" >:: test_parity_vs_scalar_reference;
         "test_period_one_passthrough" >:: test_period_one_passthrough;
       ]

let () = run_test_tt_main suite
