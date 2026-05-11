open OUnit2
open Core
open Matchers
open Synthetic

let _default_cfg ?(n_symbols = 5) ?(target = 200) ?(seed = 17) () =
  Synth_v3.default_config ~n_symbols
    ~start_date:(Date.of_string "2030-01-01")
    ~start_price:100.0 ~target_length_days:target ~seed

let _unwrap_or_fail msg = function
  | Ok v -> v
  | Error e -> assert_failure (msg ^ ": " ^ Status.show e)

(* ------------------------------------------------------------------ *)
(* Universe shape                                                       *)
(* ------------------------------------------------------------------ *)

let test_universe_n_symbols _ =
  let cfg = _default_cfg ~n_symbols:10 ~target:50 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  assert_that u.symbols (size_is 10)

let test_each_symbol_target_length _ =
  let target = 80 in
  let cfg = _default_cfg ~n_symbols:5 ~target () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let n_wrong_length =
    List.count u.symbols ~f:(fun (_, bars) -> List.length bars <> target)
  in
  assert_that n_wrong_length (equal_to 0)

let test_default_symbol_names _ =
  let cfg = _default_cfg ~n_symbols:3 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let names = List.map u.symbols ~f:fst in
  assert_that names
    (elements_are
       [ equal_to "SYNTH_0001"; equal_to "SYNTH_0002"; equal_to "SYNTH_0003" ])

let test_explicit_symbol_names _ =
  let cfg =
    {
      (_default_cfg ~n_symbols:3 ()) with
      symbols = Some [ "AAA"; "BBB"; "CCC" ];
    }
  in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let names = List.map u.symbols ~f:fst in
  assert_that names
    (elements_are [ equal_to "AAA"; equal_to "BBB"; equal_to "CCC" ])

(* ------------------------------------------------------------------ *)
(* Calendar alignment across symbols                                    *)
(* ------------------------------------------------------------------ *)

let test_all_symbols_share_dates _ =
  let cfg = _default_cfg ~n_symbols:6 ~target:40 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let bar_dates =
    List.map u.symbols ~f:(fun (_, bars) ->
        List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date))
  in
  match bar_dates with
  | [] -> assert_failure "empty universe"
  | first :: rest ->
      let n_misaligned =
        List.count rest ~f:(fun dates -> not (List.equal Date.equal first dates))
      in
      assert_that n_misaligned (equal_to 0)

let test_dates_business_days_only _ =
  let cfg = _default_cfg ~n_symbols:2 ~target:40 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let _, bars0 = List.hd_exn u.symbols in
  let n_weekend_bars =
    List.count bars0 ~f:(fun (b : Types.Daily_price.t) ->
        match Date.day_of_week b.date with Sat | Sun -> true | _ -> false)
  in
  assert_that n_weekend_bars (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Determinism                                                          *)
(* ------------------------------------------------------------------ *)

let _close_series bars =
  List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.close_price)

let test_determinism_same_seed _ =
  let cfg = _default_cfg ~n_symbols:5 ~target:100 ~seed:42 () in
  let u1 = _unwrap_or_fail "first" (Synth_v3.generate cfg) in
  let u2 = _unwrap_or_fail "second" (Synth_v3.generate cfg) in
  let closes1 = List.map u1.symbols ~f:(fun (_, b) -> _close_series b) in
  let closes2 = List.map u2.symbols ~f:(fun (_, b) -> _close_series b) in
  assert_that
    (List.equal (List.equal Float.equal) closes1 closes2)
    (equal_to true)

let test_determinism_different_seed_differs _ =
  let cfg1 = _default_cfg ~n_symbols:5 ~target:100 ~seed:42 () in
  let cfg2 = _default_cfg ~n_symbols:5 ~target:100 ~seed:99 () in
  let u1 = _unwrap_or_fail "seed=42" (Synth_v3.generate cfg1) in
  let u2 = _unwrap_or_fail "seed=99" (Synth_v3.generate cfg2) in
  let closes1 = List.map u1.symbols ~f:(fun (_, b) -> _close_series b) in
  let closes2 = List.map u2.symbols ~f:(fun (_, b) -> _close_series b) in
  assert_that
    (List.equal (List.equal Float.equal) closes1 closes2)
    (equal_to false)

(* Verify per-symbol streams are *independent* — two different symbols
   shouldn't produce identical bars, because the per-symbol seed differs. *)
let test_different_symbols_differ _ =
  let cfg = _default_cfg ~n_symbols:3 ~target:100 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  match u.symbols with
  | (_, bars0) :: (_, bars1) :: _ ->
      assert_that
        (List.equal Float.equal (_close_series bars0) (_close_series bars1))
        (equal_to false)
  | _ -> assert_failure "expected at least 2 symbols"

(* ------------------------------------------------------------------ *)
(* OHLC well-formed across all symbols                                  *)
(* ------------------------------------------------------------------ *)

let test_ohlc_well_formed_all_symbols _ =
  let cfg = _default_cfg ~n_symbols:5 ~target:200 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let ok_bar (b : Types.Daily_price.t) =
    Float.(b.low_price <= b.open_price)
    && Float.(b.open_price <= b.high_price)
    && Float.(b.low_price <= b.close_price)
    && Float.(b.close_price <= b.high_price)
    && Float.(b.close_price > 0.0)
    && Float.is_finite b.close_price
  in
  let n_malformed =
    List.sum
      (module Int)
      u.symbols
      ~f:(fun (_, bars) -> List.count bars ~f:(fun b -> not (ok_bar b)))
  in
  assert_that n_malformed (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Cross-sectional correlation matches target ~0.5                       *)
(* ------------------------------------------------------------------ *)

let _daily_returns bars =
  match bars with
  | [] | [ _ ] -> []
  | _ ->
      let closes = Array.of_list (_close_series bars) in
      let n = Array.length closes in
      let out = Array.create ~len:(n - 1) 0.0 in
      for i = 1 to n - 1 do
        out.(i - 1) <- Float.log (closes.(i) /. closes.(i - 1))
      done;
      Array.to_list out

let _pearson_correlation xs ys =
  let n = List.length xs in
  if n < 2 then 0.0
  else
    let xs_arr = Array.of_list xs in
    let ys_arr = Array.of_list ys in
    let mean a =
      Array.fold a ~init:0.0 ~f:Float.( + ) /. Float.of_int (Array.length a)
    in
    let mx = mean xs_arr in
    let my = mean ys_arr in
    let cov = ref 0.0 in
    let vx = ref 0.0 in
    let vy = ref 0.0 in
    for i = 0 to n - 1 do
      let dx = xs_arr.(i) -. mx in
      let dy = ys_arr.(i) -. my in
      cov := !cov +. (dx *. dy);
      vx := !vx +. (dx *. dx);
      vy := !vy +. (dy *. dy)
    done;
    if Float.(!vx = 0.0) || Float.(!vy = 0.0) then 0.0
    else !cov /. Float.sqrt (!vx *. !vy)

(* Pairwise correlation acceptance test from the m7 plan.
   50 symbols × 5_000 daily returns ≈ 1225 pairs. With default β-distribution
   (mean=1.0, stddev=0.4) and default idio scale (omega=1e-5, σ≈1%/day) the
   expected average pairwise correlation lands near 0.5. We pin a wide band
   [0.3, 0.7] to accommodate distribution-tail draws across regimes. *)
let test_cross_sectional_correlation _ =
  let cfg = _default_cfg ~n_symbols:50 ~target:5_000 ~seed:7 () in
  let u = _unwrap_or_fail "generate failed" (Synth_v3.generate cfg) in
  let returns = List.map u.symbols ~f:(fun (_, bars) -> _daily_returns bars) in
  let returns_arr = Array.of_list returns in
  let n = Array.length returns_arr in
  let total = ref 0.0 in
  let count = ref 0 in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      total := !total +. _pearson_correlation returns_arr.(i) returns_arr.(j);
      incr count
    done
  done;
  let avg = !total /. Float.of_int !count in
  assert_that avg (is_between (module Float_ord) ~low:0.3 ~high:0.7)

(* ------------------------------------------------------------------ *)
(* Validation paths                                                     *)
(* ------------------------------------------------------------------ *)

let test_validation_zero_n_symbols _ =
  let cfg = _default_cfg ~n_symbols:0 () in
  assert_that (Synth_v3.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_zero_start_price _ =
  let cfg = { (_default_cfg ()) with start_price = 0.0 } in
  assert_that (Synth_v3.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_symbol_list_mismatch _ =
  let cfg =
    { (_default_cfg ~n_symbols:3 ()) with symbols = Some [ "A"; "B" ] }
  in
  assert_that (Synth_v3.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_bad_loading_dist _ =
  let cfg =
    {
      (_default_cfg ()) with
      loading_distribution =
        { Factor_model.default_loading_distribution with stddev = 0.0 };
    }
  in
  assert_that (Synth_v3.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_bad_idio_dist _ =
  let cfg =
    {
      (_default_cfg ()) with
      idio_distribution =
        { Factor_model.default_idio_distribution with alpha = 0.6; beta = 0.5 };
    }
  in
  assert_that (Synth_v3.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_bad_market_propagates _ =
  let cfg = _default_cfg () in
  let bad_market = { cfg.market with target_length_days = 0 } in
  let bad = { cfg with market = bad_market } in
  assert_that (Synth_v3.generate bad) (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* default_symbol_names: shape                                           *)
(* ------------------------------------------------------------------ *)

let test_default_symbol_names_padded _ =
  let names = Synth_v3.default_symbol_names ~n:3 in
  assert_that names
    (elements_are
       [ equal_to "SYNTH_0001"; equal_to "SYNTH_0002"; equal_to "SYNTH_0003" ])

let test_default_symbol_names_zero _ =
  let names = Synth_v3.default_symbol_names ~n:0 in
  assert_that names (size_is 0)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "synth_v3"
  >::: [
         (* shape *)
         "universe n_symbols matches request" >:: test_universe_n_symbols;
         "each symbol's bar length matches target"
         >:: test_each_symbol_target_length;
         "default symbol names" >:: test_default_symbol_names;
         "explicit symbol names" >:: test_explicit_symbol_names;
         (* calendar alignment *)
         "all symbols share date sequence" >:: test_all_symbols_share_dates;
         "dates are business days only" >:: test_dates_business_days_only;
         (* determinism *)
         "determinism: same seed" >:: test_determinism_same_seed;
         "different seed produces different universe"
         >:: test_determinism_different_seed_differs;
         "different symbols produce different streams"
         >:: test_different_symbols_differ;
         (* well-formedness *)
         "OHLC well-formed across all symbols"
         >:: test_ohlc_well_formed_all_symbols;
         (* cross-section correlation (acceptance test) *)
         "average pairwise correlation lands ~0.5"
         >:: test_cross_sectional_correlation;
         (* validation *)
         "validation: zero n_symbols" >:: test_validation_zero_n_symbols;
         "validation: zero start_price" >:: test_validation_zero_start_price;
         "validation: symbol list length mismatch"
         >:: test_validation_symbol_list_mismatch;
         "validation: bad loading distribution"
         >:: test_validation_bad_loading_dist;
         "validation: bad idio distribution" >:: test_validation_bad_idio_dist;
         "validation: bad market config propagates"
         >:: test_validation_bad_market_propagates;
         (* default symbol names *)
         "default_symbol_names: padded format"
         >:: test_default_symbol_names_padded;
         "default_symbol_names: zero n returns empty"
         >:: test_default_symbol_names_zero;
       ]

let () = run_test_tt_main suite
