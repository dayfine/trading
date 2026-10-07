(** Experiment-flag discipline pins for the #3137 cash yield (R1 default-off, R2
    axis reachability), plus the committed T-bill series.

    R1: the shipped default is [No_yield] with a 10 bp fee, so no run reads a
    rate file or accrues interest. R2: both fields resolve through the real
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path), including a
    variant-to-variant override. The committed [macro/tbill_3m_dtb3.csv] (FRED
    DTB3) parses and covers the full 26y window from 2000-01-03. The part-2
    [dividend_crediting] flag gets the same R1 / R2 pins. *)

open OUnit2
open Core
open Matchers
module Cash_yield = Trading_simulation_cash_yield.Cash_yield

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "GOOG" ] ~index_symbol:"GSPCX"

let _after overlays =
  Backtest.Overlay_validator.apply_overrides (_default_config ())
    (List.map overlays ~f:Sexp.of_string)

let _fields (c : Weinstein_strategy.config) = (c.cash_yield, c.cash_yield_fee_bp)

let test_default_is_no_yield _ =
  assert_that
    (_fields (_default_config ()))
    (equal_to (Cash_yield.No_yield, Cash_yield.default_fee_bp))

let test_axis_resolves_via_overlay_validator _ =
  assert_that
    [
      _fields (_after [ "((cash_yield (Constant 4.5)))" ]);
      _fields
        (_after
           [
             "((cash_yield (Constant 4.5)))";
             "((cash_yield (Series macro/tbill_3m_dtb3.csv)) \
              (cash_yield_fee_bp 35))";
           ]);
    ]
    (elements_are
       [
         equal_to (Cash_yield.Constant 4.5, Cash_yield.default_fee_bp);
         equal_to (Cash_yield.Series "macro/tbill_3m_dtb3.csv", 35.0);
       ])

(* The committed series, read the way the runner resolves it (relative to
   [TRADING_DATA_DIR], which tests point at [trading/test_data/]). *)
(* #3137 part 2: [dividend_crediting] defaults off (R1) and is an axis via the
   real [Overlay_validator] (R2), including flipping back to [false]. *)
let test_dividend_crediting_default_off_and_axis _ =
  let flag (c : Weinstein_strategy.config) = c.dividend_crediting in
  assert_that
    [
      flag (_default_config ());
      flag (_after [ "((dividend_crediting true))" ]);
      flag
        (_after
           [ "((dividend_crediting true))"; "((dividend_crediting false))" ]);
    ]
    (elements_are [ equal_to false; equal_to true; equal_to false ])

(* #3173: [split_dividend_guard] defaults off (R1), is an axis via the real
   [Overlay_validator] (R2), and arms [Panel_corporate_actions.split_guard]
   only when on. *)
let test_split_dividend_guard_default_off_and_axis _ =
  let flag (c : Weinstein_strategy.config) = c.split_dividend_guard in
  let armed config =
    Option.is_some
      (Backtest.Panel_corporate_actions.split_guard ~config
         ~data_dir:(Fpath.v "/nonexistent"))
  in
  let on = _after [ "((split_dividend_guard true))" ] in
  assert_that
    [
      (flag (_default_config ()), armed (_default_config ()));
      (flag on, armed on);
      ( flag
          (_after
             [
               "((split_dividend_guard true))"; "((split_dividend_guard false))";
             ]),
        false );
    ]
    (elements_are
       [
         equal_to (false, false); equal_to (true, true); equal_to (false, false);
       ])

(* Unarmed, the strategy's bar reader is handed back physically unchanged;
   armed, it carries the guard. The end-of-run line names both counts. *)
let test_split_guard_reader_and_summary _ =
  let reader = Weinstein_strategy.Bar_reader.empty () in
  let guard = Split_dividend_guard.of_data_dir ~data_dir:(Fpath.v "/x") () in
  let module P = Backtest.Panel_corporate_actions in
  assert_that
    ( phys_equal (P.guard_bar_reader None reader) reader,
      Option.is_some
        (Weinstein_strategy.Bar_reader.split_guard
           (P.guard_bar_reader (Some guard) reader)),
      P.split_guard_summary guard )
    (equal_to
       (true, true, "Panel_runner: split_dividend_guard rejected=0 no_files=0"))

let test_committed_tbill_series_covers_window _ =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
  let resolved =
    Cash_yield.resolve (Series "macro/tbill_3m_dtb3.csv") ~fee_bp:10.0 ~data_dir
  in
  assert_that
    (Result.map resolved ~f:(fun r ->
         let s = Option.value_exn r in
         ( Cash_yield.net_annual_pct s (Date.of_string "2000-01-03"),
           Cash_yield.net_annual_pct s (Date.of_string "2026-06-30") )))
    (is_ok_and_holds
       (pair
          (is_ok_and_holds (gt (module Float_ord) 4.0))
          (is_ok_and_holds (gt (module Float_ord) 0.0))))

let suite =
  "cash_yield_overlays"
  >::: [
         "default is no yield" >:: test_default_is_no_yield;
         "axis resolves via overlay validator"
         >:: test_axis_resolves_via_overlay_validator;
         "dividend crediting default off and an axis"
         >:: test_dividend_crediting_default_off_and_axis;
         "split dividend guard default off and an axis"
         >:: test_split_dividend_guard_default_off_and_axis;
         "split guard reader and summary"
         >:: test_split_guard_reader_and_summary;
         "committed T-bill series covers the window"
         >:: test_committed_tbill_series_covers_window;
       ]

let () = run_test_tt_main suite
