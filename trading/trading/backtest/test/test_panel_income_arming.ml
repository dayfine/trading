(* Pin the config-to-simulator wiring through the real panel runner. *)
open Core
open OUnit2
open Matchers
module Cash_yield = Trading_simulation_cash_yield.Cash_yield
module M = Trading_simulation_types.Metric_types

let _date = Date.of_string

let _bars =
  List.map [ "2024-01-02"; "2024-01-03"; "2024-01-04"; "2024-01-05" ]
    ~f:(fun d : Types.Daily_price.t ->
      {
        date = _date d;
        open_price = 50.0;
        high_price = 50.0;
        low_price = 50.0;
        close_price = 50.0;
        adjusted_close = 50.0;
        volume = 1_000_000;
        active_through = None;
      })

let _run name overrides =
  Test_helpers.with_test_data name
    [ ("AAPL", _bars) ]
    ~f:(fun data_dir ->
      Corporate_actions.write_dividends ~data_dir "AAPL"
        [
          {
            Corporate_actions.ex_date = _date "2024-01-05";
            unadjusted_amount = Some 0.25;
            adjusted_amount = 0.25;
          };
        ]
      |> Test_helpers.ok_or_fail_status;
      let config =
        Weinstein_strategy.default_config ~universe:[ "AAPL" ]
          ~index_symbol:"AAPL"
        |> fun c ->
        Backtest.Overlay_validator.apply_overrides c
          (List.map overrides ~f:Sexp.of_string)
      in
      let cash_yield =
        Cash_yield.resolve config.cash_yield ~fee_bp:config.cash_yield_fee_bp
          ~data_dir:(Fpath.to_string (Data_path.default_data_dir ()))
        |> Result.map_error ~f:Status.show
        |> Result.ok_or_failwith
      in
      let input : Backtest.Panel_runner.input =
        {
          data_dir_fpath = data_dir;
          ticker_sectors = Hashtbl.create (module String);
          ad_bars = [];
          breadth_bars = [];
          config;
          all_symbols = [ "AAPL" ];
          cash_yield;
        }
      in
      let result, _, _, _, _, _ =
        Backtest.Panel_runner.run ~input ~start_date:(_date "2024-01-02")
          ~end_date:(_date "2024-01-06") ~warmup_days:0 ~initial_cash:100_000.0
          ~commission:{ Trading_engine.Types.per_share = 0.0; minimum = 0.0 }
          ~strategy_choice:
            (Backtest.Strategy_choice.Bah_benchmark { symbol = "AAPL" })
          ()
      in
      result.metrics)

let test_cash_yield_arming _ =
  (* Cash yield now defaults ON. No_yield is the explicit unarmed baseline. *)
  let default = _run "panel_income_default" [] in
  let off = _run "panel_income_no_yield" [ "((cash_yield No_yield))" ] in
  assert_that
    (Map.find default M.CashInterestTotal, Map.find off M.CashInterestTotal)
    (pair (is_some_and (gt (module Float_ord) 0.0)) is_none)

let test_dividend_arming _ =
  (* The enabled run pays a held position; the default emits no income key. *)
  let off = _run "panel_dividend_off" [ "((cash_yield No_yield))" ] in
  let on =
    _run "panel_dividend_on"
      [ "((cash_yield No_yield) (dividend_crediting true))" ]
  in
  assert_that
    (Map.find off M.DividendIncomeTotal, Map.find on M.DividendIncomeTotal)
    (pair is_none (is_some_and (gt (module Float_ord) 0.0)))

let () =
  run_test_tt_main
    ("panel_income_arming"
    >::: [
           "cash yield default arms panel runner; No_yield disarms it"
           >:: test_cash_yield_arming;
           "dividend flag arms panel runner; default omits metric"
           >:: test_dividend_arming;
         ])
