open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Ema_kernel = Data_panel.Ema_kernel
module BA2 = Bigarray.Array2

(* Scalar reference EMA: produces a float array of length [n], with NaN at
   indices [0..period-2] and the standard EMA recurrence afterwards. The
   summation order mirrors [Ema_kernel] exactly: warmup is left-to-right
   accumulation; recurrence is [alpha *. new_ +. (1 -. alpha) *. prev].

   For maximum parity, the warmup uses the exact same expression form as the
   kernel ([acc := !acc +. read]) and the recurrence binds [new_v] and
   [prev] to local variables before the multiply-add — same as the kernel. *)
let _scalar_ema (data : float array) (period : int) : float array =
  let n = Array.length data in
  let out = Array.create ~len:n Float.nan in
  if n >= period then begin
    let acc = ref 0.0 in
    for k = 0 to period - 1 do
      acc := !acc +. data.(k)
    done;
    out.(period - 1) <- !acc /. Float.of_int period;
    let alpha = 2.0 /. (Float.of_int period +. 1.0) in
    let one_minus_a = 1.0 -. alpha in
    for t = period to n - 1 do
      let new_v = data.(t) in
      let prev = out.(t - 1) in
      out.(t) <- (alpha *. new_v) +. (one_minus_a *. prev)
    done
  end;
  out

(* Deterministic random walk: seed 42, standard LCG so the test is independent
   of platform RNG quirks. Returns [n] values starting at [start] with steps
   uniform in [-step_max, step_max]. *)
let _random_walk ~seed ~n ~start ~step_max : float array =
  let state = ref (Int64.of_int seed) in
  let next_uniform () =
    (* Numerical Recipes LCG, masked to 32 bits. *)
    let next =
      Int64.bit_and
        (Int64.( + ) (Int64.( * ) !state 1664525L) 1013904223L)
        0xFFFFFFFFL
    in
    state := next;
    let v = Int64.to_int_exn next in
    Float.of_int v /. 4294967296.0 (* in [0, 1) *)
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

let _advance_full ~input ~output ~period ~n_days =
  for t = 0 to n_days - 1 do
    Ema_kernel.advance ~input ~output ~period ~t
  done

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

let test_warmup_and_alpha_helpers _ =
  assert_that
    (Ema_kernel.warmup ~period:1, Ema_kernel.warmup ~period:5)
    (pair (equal_to 0) (equal_to 4));
  assert_that
    (Ema_kernel.alpha ~period:9, Ema_kernel.alpha ~period:1)
    (pair (float_equal 0.2) (float_equal 1.0))

let test_warmup_writes_nan _ =
  let panels, _ = _build_panel ~n_symbols:3 ~n_days:10 in
  let input = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols:3 ~n_days:10 in
  Ema_kernel.advance ~input ~output ~period:5 ~t:0;
  Ema_kernel.advance ~input ~output ~period:5 ~t:3;
  assert_that
    (Float.is_nan (BA2.get output 0 0), Float.is_nan (BA2.get output 1 3))
    (pair (equal_to true) (equal_to true))

let test_warmup_is_simple_average _ =
  let panels, _ = _build_panel ~n_symbols:1 ~n_days:5 in
  let input = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols:1 ~n_days:5 in
  for t = 0 to 4 do
    Ema_kernel.advance ~input ~output ~period:3 ~t
  done;
  let expected_warmup =
    (BA2.get input 0 0 +. BA2.get input 0 1 +. BA2.get input 0 2) /. 3.0
  in
  assert_that (BA2.get output 0 2) (float_equal expected_warmup)

let test_recurrence_canonical_values _ =
  (* Mirrors test_calculate_ema in indicators/ema/test/test_ema.ml: input
     [100, 101, 102, 103, 104] period=2 -> [NaN, 100.5, 101.5, 102.5, 103.5] *)
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
    Ema_kernel.advance ~input:close ~output ~period:2 ~t
  done;
  assert_that
    [
      Float.is_nan (BA2.get output 0 0);
      Float.equal (BA2.get output 0 1) 100.5;
      Float.equal (BA2.get output 0 2) 101.5;
      Float.equal (BA2.get output 0 3) 102.5;
      Float.equal (BA2.get output 0 4) 103.5;
    ]
    (equal_to [ true; true; true; true; true ])

let test_parity_vs_scalar_reference _ =
  (* 100-symbol 1-year (252 trading days) parity test. Per dispatch:
     run BOTH bit-identical AND tolerance <= 1e-9 cases.

     With the scalar reference written to mirror the kernel's expression
     form (warmup = left-to-right [+.] accumulation; recurrence = bind
     [new_v] and [prev] to locals, then [(alpha *. new_v) +. (one_minus_a
     *. prev)]), the kernel produces output bit-identical to the reference
     across 100 symbols x 252 days. An earlier reference variant that
     inlined [data.(t)] and [out.(t-1)] directly into the multiply-add
     drifted by 1-6 ULP — the difference comes from instruction-scheduling
     latitude when the read isn't bound to a named local; the kernel and
     reference must use identical OCaml expression form for bit-identical
     output across Bigarray and float-array storage. *)
  let n_symbols = 100 in
  let n_days = 252 in
  let period = 50 in
  let panels, series = _build_panel ~n_symbols ~n_days in
  let input = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols ~n_days in
  _advance_full ~input ~output ~period ~n_days;
  let reference = Array.map series ~f:(fun walk -> _scalar_ema walk period) in
  let max_ulp, max_abs =
    _max_ulp_drift output reference n_symbols n_days period
  in
  let msg =
    Printf.sprintf "max_ulp = %d, max abs diff = %.3e" max_ulp max_abs
  in
  (* Bit-identical (asserted): zero ULP, zero abs diff. *)
  assert_that max_ulp (equal_to ~msg 0);
  (* Tolerance <= 1e-9 (asserted): trivially holds when bit-identical, but
     phrased explicitly per the dispatch's "BOTH cases" requirement. *)
  assert_that max_abs (le (module Float_ord) 1e-9)

let suite =
  "Ema_kernel tests"
  >::: [
         "test_warmup_and_alpha_helpers" >:: test_warmup_and_alpha_helpers;
         "test_warmup_writes_nan" >:: test_warmup_writes_nan;
         "test_warmup_is_simple_average" >:: test_warmup_is_simple_average;
         "test_recurrence_canonical_values" >:: test_recurrence_canonical_values;
         "test_parity_vs_scalar_reference" >:: test_parity_vs_scalar_reference;
       ]

let () = run_test_tt_main suite
