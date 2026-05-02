open OUnit2
open Core
open Matchers
open Synthetic

(* ------------------------------------------------------------------ *)
(* Statistical helpers — kept inline; they are test-only.              *)
(* ------------------------------------------------------------------ *)

let _log_returns (bars : Types.Daily_price.t list) : float list =
  let closes = List.map bars ~f:(fun b -> b.close_price) in
  match closes with
  | [] | [ _ ] -> []
  | first :: rest ->
      let _, rs =
        List.fold rest ~init:(first, []) ~f:(fun (prev, acc) curr ->
            (curr, Float.log (curr /. prev) :: acc))
      in
      List.rev rs

let _mean xs =
  let n = List.length xs in
  if n = 0 then 0.0 else List.sum (module Float) xs ~f:Fn.id /. Float.of_int n

let _variance xs =
  let m = _mean xs in
  let n = List.length xs in
  if n <= 1 then 0.0
  else
    List.sum (module Float) xs ~f:(fun x -> (x -. m) ** 2.0) /. Float.of_int n

let _skew xs =
  let m = _mean xs in
  let v = _variance xs in
  let s = Float.sqrt v in
  let n = Float.of_int (List.length xs) in
  if Float.(s <= 0.0) || Float.(n = 0.0) then 0.0
  else List.sum (module Float) xs ~f:(fun x -> ((x -. m) /. s) ** 3.0) /. n

let _kurt xs =
  let m = _mean xs in
  let v = _variance xs in
  let n = Float.of_int (List.length xs) in
  if Float.(v <= 0.0) || Float.(n = 0.0) then 0.0
  else
    List.sum (module Float) xs ~f:(fun x -> (x -. m) ** 4.0) /. n /. (v ** 2.0)

let _autocorr_lag1 xs =
  let m = _mean xs in
  let n = List.length xs in
  if n <= 1 then 0.0
  else
    let arr = Array.of_list xs in
    let num = ref 0.0 in
    let den = ref 0.0 in
    for i = 0 to n - 2 do
      num := !num +. ((arr.(i) -. m) *. (arr.(i + 1) -. m))
    done;
    for i = 0 to n - 1 do
      den := !den +. ((arr.(i) -. m) ** 2.0)
    done;
    if Float.(!den <= 0.0) then 0.0 else !num /. !den

(* Tolerance band: actual value must lie in [target * (1 - frac), target *
   (1 + frac)], with a small additive pad so a near-zero source moment
   doesn't blow up the relative band. *)
let _within_relative ~target ~frac =
  let abs_pad = 0.02 in
  let half_width = Float.max (Float.abs target *. frac) abs_pad in
  (target -. half_width, target +. half_width)

(* ------------------------------------------------------------------ *)
(* Fixture: a small synthetic SPY-like source                           *)
(* ------------------------------------------------------------------ *)

let _source_2000 () =
  Source_loader.synthetic_spy_like
    ~start_date:(Date.of_string "2000-01-03")
    ~n_days:2000 ~seed:42

let _default_config ~target =
  {
    Block_bootstrap.target_length_days = target;
    mean_block_length = 30;
    seed = 17;
    start_date = Date.of_string "2030-01-01";
    start_price = 100.0;
  }

(* Set of source one-step log-returns, rounded to a stable bucket. The
   bootstrap replays these exactly; if any synth return falls outside this
   set (within rounding) something has leaked. *)
let _source_return_bucket_set source =
  let closes =
    List.map source ~f:(fun (b : Types.Daily_price.t) -> b.close_price)
    |> Array.of_list
  in
  let n = Array.length closes in
  let bucket = 1_000_000.0 in
  let s =
    Hash_set.create
      (module struct
        type t = int [@@deriving compare, hash, sexp_of]
      end)
  in
  for i = 1 to n - 1 do
    let r = Float.log (closes.(i) /. closes.(i - 1)) in
    Hash_set.add s (Int.of_float (Float.round_nearest (r *. bucket)))
  done;
  s

let _synth_returns_in_source_set source bars =
  let s = _source_return_bucket_set source in
  let bucket = 1_000_000.0 in
  let returns = _log_returns bars in
  List.for_all returns ~f:(fun r ->
      Hash_set.mem s (Int.of_float (Float.round_nearest (r *. bucket))))

(* Force a result; tests for determinism/leakage need the unwrapped list to
   build cross-cutting predicates that don't fit the single-matcher mould.
   We assert in the caller that the result is Ok before using this. *)
let _unwrap_or_fail msg = function
  | Ok v -> v
  | Error e -> assert_failure (msg ^ ": " ^ Status.show e)

(* ------------------------------------------------------------------ *)
(* Test 1: output length matches request                                *)
(* ------------------------------------------------------------------ *)

let test_output_length _ =
  let source = _source_2000 () in
  let result =
    Block_bootstrap.generate ~source ~config:(_default_config ~target:500)
  in
  assert_that result (is_ok_and_holds (size_is 500))

(* ------------------------------------------------------------------ *)
(* Test 2: same seed → byte-for-byte identical output                   *)
(* ------------------------------------------------------------------ *)

let test_determinism_same_seed _ =
  let source = _source_2000 () in
  let cfg = _default_config ~target:200 in
  let bars1 =
    _unwrap_or_fail "first run failed"
      (Block_bootstrap.generate ~source ~config:cfg)
  in
  let bars2 =
    _unwrap_or_fail "second run failed"
      (Block_bootstrap.generate ~source ~config:cfg)
  in
  assert_that (List.equal Types.Daily_price.equal bars1 bars2) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Test 3: different seed → different output                            *)
(* ------------------------------------------------------------------ *)

let test_different_seeds_differ _ =
  let source = _source_2000 () in
  let cfg1 = _default_config ~target:200 in
  let cfg2 = { cfg1 with seed = 99 } in
  let bars1 =
    _unwrap_or_fail "seed=17 run failed"
      (Block_bootstrap.generate ~source ~config:cfg1)
  in
  let bars2 =
    _unwrap_or_fail "seed=99 run failed"
      (Block_bootstrap.generate ~source ~config:cfg2)
  in
  assert_that (List.equal Types.Daily_price.equal bars1 bars2) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Test 4: dates strictly increase (business days only)                 *)
(* ------------------------------------------------------------------ *)

let test_dates_monotonic_business_days _ =
  let source = _source_2000 () in
  let cfg = _default_config ~target:50 in
  let bars =
    _unwrap_or_fail "generate failed"
      (Block_bootstrap.generate ~source ~config:cfg)
  in
  let dates = List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date) in
  let pairs = List.zip_exn (List.drop_last_exn dates) (List.tl_exn dates) in
  let strictly_increasing =
    List.for_all pairs ~f:(fun (a, b) -> Date.compare a b < 0)
  in
  let all_weekdays =
    List.for_all dates ~f:(fun d ->
        match Date.day_of_week d with Sat | Sun -> false | _ -> true)
  in
  assert_that strictly_increasing (equal_to true);
  assert_that all_weekdays (equal_to true)

(* ------------------------------------------------------------------ *)
(* Test 5: every replayed log-return came from the source (no leakage)  *)
(* ------------------------------------------------------------------ *)

let test_no_lookahead_leakage _ =
  let source = _source_2000 () in
  let cfg = _default_config ~target:300 in
  let bars =
    _unwrap_or_fail "generate failed"
      (Block_bootstrap.generate ~source ~config:cfg)
  in
  assert_that (_synth_returns_in_source_set source bars) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Test 6: statistical fidelity — skew/kurt/autocorr within ±10%        *)
(* ------------------------------------------------------------------ *)

let test_statistical_fidelity _ =
  let source = _source_2000 () in
  let source_returns = _log_returns source in
  let src_skew = _skew source_returns in
  let src_kurt = _kurt source_returns in
  let src_acf1 = _autocorr_lag1 source_returns in
  let cfg = _default_config ~target:8000 in
  let bars =
    _unwrap_or_fail "generate failed"
      (Block_bootstrap.generate ~source ~config:cfg)
  in
  let synth_returns = _log_returns bars in
  let frac = 0.10 in
  let skew_lo, skew_hi = _within_relative ~target:src_skew ~frac in
  let kurt_lo, kurt_hi = _within_relative ~target:src_kurt ~frac in
  let acf_lo, acf_hi = _within_relative ~target:src_acf1 ~frac in
  assert_that (_skew synth_returns)
    (is_between (module Float_ord) ~low:skew_lo ~high:skew_hi);
  assert_that (_kurt synth_returns)
    (is_between (module Float_ord) ~low:kurt_lo ~high:kurt_hi);
  assert_that
    (_autocorr_lag1 synth_returns)
    (is_between (module Float_ord) ~low:acf_lo ~high:acf_hi)

(* ------------------------------------------------------------------ *)
(* Test 7: validation — empty source                                    *)
(* ------------------------------------------------------------------ *)

let test_validation_empty_source _ =
  let result =
    Block_bootstrap.generate ~source:[] ~config:(_default_config ~target:50)
  in
  assert_that result (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Test 8: validation — non-positive target length                      *)
(* ------------------------------------------------------------------ *)

let test_validation_zero_target _ =
  let source = _source_2000 () in
  let cfg = _default_config ~target:0 in
  let result = Block_bootstrap.generate ~source ~config:cfg in
  assert_that result (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Test 9: validation — source shorter than mean_block_length           *)
(* ------------------------------------------------------------------ *)

let test_validation_source_too_short _ =
  let short_source =
    Source_loader.synthetic_spy_like
      ~start_date:(Date.of_string "2000-01-03")
      ~n_days:5 ~seed:7
  in
  let cfg = _default_config ~target:100 in
  let result = Block_bootstrap.generate ~source:short_source ~config:cfg in
  assert_that result (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Test 10: validation — non-positive mean_block_length                 *)
(* ------------------------------------------------------------------ *)

let test_validation_zero_mean_block_length _ =
  let source = _source_2000 () in
  let cfg = { (_default_config ~target:200) with mean_block_length = 0 } in
  let result = Block_bootstrap.generate ~source ~config:cfg in
  assert_that result (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Test 11: validation — non-positive start_price                       *)
(* ------------------------------------------------------------------ *)

let test_validation_zero_start_price _ =
  let source = _source_2000 () in
  let cfg = { (_default_config ~target:200) with start_price = 0.0 } in
  let result = Block_bootstrap.generate ~source ~config:cfg in
  assert_that result (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* Test 12: Source_loader.load_csv — missing file → NotFound            *)
(* ------------------------------------------------------------------ *)

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_block_bootstrap" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let test_load_csv_missing_file _ =
  _with_temp_dir (fun dir ->
      let result =
        Source_loader.load_csv ~path:(Filename.concat dir "does_not_exist.csv")
      in
      assert_that result (is_error_with Status.NotFound))

(* ------------------------------------------------------------------ *)
(* Test 13: Source_loader.load_csv — malformed CSV → Invalid_argument   *)
(* ------------------------------------------------------------------ *)

let test_load_csv_malformed _ =
  _with_temp_dir (fun dir ->
      let path = Filename.concat dir "malformed.csv" in
      (* Header (skipped by parser) plus a row missing columns. The parser
         requires exactly 7 comma-separated columns; "not,enough,cols"
         triggers the "Expected 7 columns" branch which surfaces as
         Status.Invalid_argument. *)
      Out_channel.write_all path
        ~data:
          "date,open,high,low,close,adjusted_close,volume\nnot,enough,cols\n";
      let result = Source_loader.load_csv ~path in
      assert_that result (is_error_with Status.Invalid_argument))

(* ------------------------------------------------------------------ *)
(* Test suite                                                           *)
(* ------------------------------------------------------------------ *)

let suite =
  "block_bootstrap"
  >::: [
         "output length" >:: test_output_length;
         "determinism — same seed identical" >:: test_determinism_same_seed;
         "determinism — different seeds differ" >:: test_different_seeds_differ;
         "dates are monotonic business days"
         >:: test_dates_monotonic_business_days;
         "no look-ahead leakage" >:: test_no_lookahead_leakage;
         "statistical fidelity within ±10%" >:: test_statistical_fidelity;
         "validation: empty source" >:: test_validation_empty_source;
         "validation: zero target" >:: test_validation_zero_target;
         "validation: source too short" >:: test_validation_source_too_short;
         "validation: zero mean_block_length"
         >:: test_validation_zero_mean_block_length;
         "validation: zero start_price" >:: test_validation_zero_start_price;
         "load_csv: missing file → NotFound" >:: test_load_csv_missing_file;
         "load_csv: malformed CSV → Invalid_argument"
         >:: test_load_csv_malformed;
       ]

let () = run_test_tt_main suite
