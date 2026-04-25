open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Atr_kernel = Data_panel.Atr_kernel
module BA2 = Bigarray.Array2

(* Scalar reference Wilder ATR. Output[0] = NaN; output[1..period-1] = NaN;
   output[period] = simple mean of TR over [1..period]; output[t > period] =
   (output[t-1] * (P-1) + tr[t]) / P. Reads bound to named locals to mirror
   the kernel's expression form for bit-identical output. *)
let _tr ~h ~l ~prev_c =
  let range = h -. l in
  let gap_up = Float.abs (h -. prev_c) in
  let gap_down = Float.abs (l -. prev_c) in
  Float.max range (Float.max gap_up gap_down)

let _scalar_atr ~high ~low ~close period : float array =
  let n = Array.length close in
  let out = Array.create ~len:n Float.nan in
  if n <= period then out
  else begin
    (* Seed at t = period: simple average of TR over window [1..period]. *)
    let acc = ref 0.0 in
    for k = 1 to period do
      let h = high.(k) in
      let l = low.(k) in
      let pc = close.(k - 1) in
      let tr = _tr ~h ~l ~prev_c:pc in
      acc := !acc +. tr
    done;
    out.(period) <- !acc /. Float.of_int period;
    let pm1 = Float.of_int (period - 1) in
    let period_f = Float.of_int period in
    for t = period + 1 to n - 1 do
      let prev = out.(t - 1) in
      let h = high.(t) in
      let l = low.(t) in
      let pc = close.(t - 1) in
      let tr = _tr ~h ~l ~prev_c:pc in
      let new_v = ((prev *. pm1) +. tr) /. period_f in
      out.(t) <- new_v
    done;
    out
  end

(* OHLC random walk: close walks; high = close + half-step abs noise; low =
   close - half-step abs noise. Deterministic LCG seed for cross-platform
   reproducibility. *)
let _build_ohlc_panel ~n_symbols ~n_days ~seed_offset =
  let universe = List.init n_symbols ~f:(fun i -> Printf.sprintf "S%04d" i) in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err ->
        assert_failure (Printf.sprintf "create failed: %s" err.Status.message)
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let high = Ohlcv_panels.high panels in
  let low = Ohlcv_panels.low panels in
  let close = Ohlcv_panels.close panels in
  let highs = Array.create ~len:n_symbols [||] in
  let lows = Array.create ~len:n_symbols [||] in
  let closes = Array.create ~len:n_symbols [||] in
  for r = 0 to n_symbols - 1 do
    let state = ref (Int64.of_int (seed_offset + r)) in
    let next () =
      let next_v =
        Int64.bit_and
          (Int64.( + ) (Int64.( * ) !state 1664525L) 1013904223L)
          0xFFFFFFFFL
      in
      state := next_v;
      let v = Int64.to_int_exn next_v in
      Float.of_int v /. 4294967296.0
    in
    let h_arr = Array.create ~len:n_days 0.0 in
    let l_arr = Array.create ~len:n_days 0.0 in
    let c_arr = Array.create ~len:n_days 0.0 in
    let prev_close = ref (100.0 +. Float.of_int r) in
    for t = 0 to n_days - 1 do
      let u_close = next () in
      let u_h = next () in
      let u_l = next () in
      let close_step = ((u_close *. 2.0) -. 1.0) *. 1.5 in
      let new_close = !prev_close +. close_step in
      let h_off = u_h *. 1.0 in
      let l_off = u_l *. 1.0 in
      let h_v = new_close +. h_off in
      let l_v = new_close -. l_off in
      h_arr.(t) <- h_v;
      l_arr.(t) <- l_v;
      c_arr.(t) <- new_close;
      BA2.unsafe_set high r t h_v;
      BA2.unsafe_set low r t l_v;
      BA2.unsafe_set close r t new_close;
      prev_close := new_close
    done;
    highs.(r) <- h_arr;
    lows.(r) <- l_arr;
    closes.(r) <- c_arr
  done;
  (panels, highs, lows, closes)

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
  let panels, _, _, _ =
    _build_ohlc_panel ~n_symbols:1 ~n_days:10 ~seed_offset:7
  in
  let high = Ohlcv_panels.high panels in
  let low = Ohlcv_panels.low panels in
  let close = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols:1 ~n_days:10 in
  for t = 0 to 5 do
    Atr_kernel.advance ~high ~low ~close ~output ~period:7 ~t
  done;
  (* warmup ~period:7 = 7, so t = 0..6 are NaN. *)
  assert_that
    (List.init 7 ~f:(fun t -> Float.is_nan (BA2.get output 0 t)))
    (equal_to (List.init 7 ~f:(fun _ -> true)))

let test_canonical_values _ =
  (* Period=2, OHLC for 4 days:
     t=0: H=10 L=8  C=9
     t=1: H=12 L=9  C=11   TR(1) = max(3, |12-9|, |9-9|) = 3
     t=2: H=13 L=10 C=12   TR(2) = max(3, |13-11|, |10-11|) = 3
     t=3: H=11 L=8  C=9    TR(3) = max(3, |11-12|, |8-12|) = 4
     ATR(2) = (3+3)/2 = 3.0
     ATR(3) = (3.0 * 1 + 4) / 2 = 3.5 *)
  let n_days = 4 in
  let universe = [ "AAA" ] in
  let idx =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> assert_failure err.Status.message
  in
  let panels = Ohlcv_panels.create idx ~n_days in
  let h = Ohlcv_panels.high panels in
  let l = Ohlcv_panels.low panels in
  let c = Ohlcv_panels.close panels in
  Array.iteri [| 10.0; 12.0; 13.0; 11.0 |] ~f:(fun i v ->
      BA2.unsafe_set h 0 i v);
  Array.iteri [| 8.0; 9.0; 10.0; 8.0 |] ~f:(fun i v -> BA2.unsafe_set l 0 i v);
  Array.iteri [| 9.0; 11.0; 12.0; 9.0 |] ~f:(fun i v -> BA2.unsafe_set c 0 i v);
  let output = _make_output ~n_symbols:1 ~n_days in
  for t = 0 to n_days - 1 do
    Atr_kernel.advance ~high:h ~low:l ~close:c ~output ~period:2 ~t
  done;
  assert_that
    [
      Float.is_nan (BA2.get output 0 0);
      Float.is_nan (BA2.get output 0 1);
      Float.equal (BA2.get output 0 2) 3.0;
      Float.equal (BA2.get output 0 3) 3.5;
    ]
    (equal_to [ true; true; true; true ])

let test_parity_vs_scalar_reference _ =
  let n_symbols = 50 in
  let n_days = 252 in
  let period = 14 in
  let panels, highs, lows, closes =
    _build_ohlc_panel ~n_symbols ~n_days ~seed_offset:101
  in
  let h = Ohlcv_panels.high panels in
  let l = Ohlcv_panels.low panels in
  let c = Ohlcv_panels.close panels in
  let output = _make_output ~n_symbols ~n_days in
  for t = 0 to n_days - 1 do
    Atr_kernel.advance ~high:h ~low:l ~close:c ~output ~period ~t
  done;
  let reference =
    Array.init n_symbols ~f:(fun r ->
        _scalar_atr ~high:highs.(r) ~low:lows.(r) ~close:closes.(r) period)
  in
  let max_ulp, max_abs =
    _max_ulp_drift output reference n_symbols n_days period
  in
  let msg =
    Printf.sprintf "max_ulp = %d, max abs diff = %.3e" max_ulp max_abs
  in
  assert_that max_ulp (equal_to ~msg 0);
  assert_that max_abs (le (module Float_ord) 1e-9)

let suite =
  "Atr_kernel tests"
  >::: [
         "test_warmup_writes_nan" >:: test_warmup_writes_nan;
         "test_canonical_values" >:: test_canonical_values;
         "test_parity_vs_scalar_reference" >:: test_parity_vs_scalar_reference;
       ]

let () = run_test_tt_main suite
