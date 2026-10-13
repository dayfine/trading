(** Issue #3136: a bar reader armed with a split divisor
    ({!Bar_reader.with_split_divisor}) makes {!Liquidity_metric.dollar_adv} and
    the gates that read it score true dollars traded, [close *. volume /. F(t)].
    Unarmed (the default), every reading is the stored product.

    Fixtures: an AMZN-shaped name whose stored volume is restated for a later
    20:1 ([F = 20], stored reading 20x too high) and a C-shaped one restated for
    a later 1:10 ([F = 0.1], stored reading 1/10). *)

open OUnit2
open Core
open Matchers
open Weinstein_types
open Weinstein_strategy

let _d = Date.of_string

let _bar date ~close ~volume : Types.Daily_price.t =
  {
    date = _d date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(* Two bars before a split dated 2024-01-04 and one on it: [F = 2] before, [1]
   from the split day on. Stored dollar volumes 10k / 20k / 30k. *)
let _window =
  [
    _bar "2024-01-02" ~close:10.0 ~volume:1000;
    _bar "2024-01-03" ~close:20.0 ~volume:1000;
    _bar "2024-01-04" ~close:30.0 ~volume:1000;
  ]

let _split_on_jan_4 date =
  if Date.( < ) date (_d "2024-01-04") then 2.0 else 1.0

let test_divisor_applies_per_bar _ =
  let adv ?split_divisor aggregation =
    Liquidity_metric.dollar_adv ~aggregation ?split_divisor ~lookback_days:20
      _window
  in
  assert_that
    [
      adv Liquidity_metric.Mean;
      adv ~split_divisor:_split_on_jan_4 Liquidity_metric.Mean;
      adv ~split_divisor:_split_on_jan_4 Liquidity_metric.Median;
    ]
    (elements_are
       [
         is_some_and (float_equal 20_000.0);
         is_some_and (float_equal ((5_000.0 +. 10_000.0 +. 30_000.0) /. 3.0));
         is_some_and (float_equal 10_000.0);
       ])

(* AMZN-shaped: stored $1.5M/day, true $75k/day. C-shaped: stored $500k/day,
   true $5M/day. Twenty bars each, ending 2018-06-29. *)
let _bars ~close ~volume =
  List.init 20 ~f:(fun i ->
      _bar (Date.to_string (Date.add_days (_d "2018-06-10") i)) ~close ~volume)

let _as_of = _d "2018-06-29"
let _amzn = ("AMZN", _bars ~close:1500.0 ~volume:1000)
let _c = ("C", _bars ~close:5.0 ~volume:100_000)

let _divisor ~symbol _date =
  match symbol with "AMZN" -> 20.0 | "C" -> 0.1 | _ -> 1.0

let _reader ~armed =
  let reader = Bar_reader.of_in_memory_bars [ _amzn; _c ] in
  if armed then Bar_reader.with_split_divisor reader _divisor else reader

let _candidate ~ticker ~side : Screener.scored_candidate =
  {
    ticker;
    analysis =
      Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
        ~bars:[] ~benchmark_bars:[] ~prior_stage:None ~as_of_date:_as_of;
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry = 10.0;
    suggested_stop = 10.8;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _tickers = List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(* The default $1M entry floor. Stored: AMZN passes, C is dropped. True
   dollars: the reverse. *)
let test_entry_gate_flips_on_true_dollars _ =
  let survivors ~armed =
    Entry_liquidity_gate.apply ~config:Liquidity_config.default_config
      ~bar_reader:(_reader ~armed) ~current_date:_as_of
      [
        _candidate ~ticker:"AMZN" ~side:Trading_base.Types.Long;
        _candidate ~ticker:"C" ~side:Trading_base.Types.Long;
      ]
    |> _tickers
  in
  assert_that
    [ survivors ~armed:false; survivors ~armed:true ]
    (elements_are
       [ elements_are [ equal_to "AMZN" ]; elements_are [ equal_to "C" ] ])

let test_short_borrow_gate_reads_true_dollars _ =
  let survivors ~armed =
    Short_borrow_gate.apply ~min_dollar_adv:1_000_000.0
      ~liquidity_config:Liquidity_config.default_config
      ~bar_reader:(_reader ~armed) ~current_date:_as_of
      [
        _candidate ~ticker:"AMZN" ~side:Trading_base.Types.Short;
        _candidate ~ticker:"C" ~side:Trading_base.Types.Short;
      ]
    |> _tickers
  in
  assert_that
    [ survivors ~armed:false; survivors ~armed:true ]
    (elements_are
       [ elements_are [ equal_to "AMZN" ]; elements_are [ equal_to "C" ] ])

(* A long held since [_as_of] at a nominal price; only its symbol matters to
   the liquidity exit. *)
let _holding ticker =
  let open Trading_strategy.Position in
  let tr kind = { position_id = ticker; date = _as_of; kind } in
  let ok = function Ok p -> p | Error _ -> assert_failure "position setup" in
  let p =
    create_entering
      (tr
         (CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = 10.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> ok
  in
  let p =
    apply_transition p
      (tr (EntryFill { filled_quantity = 10.0; fill_price = 10.0 }))
    |> ok
  in
  apply_transition p
    (tr
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> ok

(* The held-position exit at a $1M hold floor (#3301 QC CP1). Stored dollars
   exit C (stored $500k/day); true dollars exit AMZN (true $75k/day) instead. *)
let test_hold_exit_flips_on_true_dollars _ =
  let positions =
    String.Map.of_alist_exn [ ("AMZN", _holding "AMZN"); ("C", _holding "C") ]
  in
  let exited ~armed =
    Liquidity_exit_runner.update
      ~config:
        {
          Liquidity_config.default_config with
          min_hold_dollar_adv = 1_000_000.0;
        }
      ~is_screening_day:true ~positions ~bar_reader:(_reader ~armed)
      ~get_price:(fun symbol ->
        Option.bind
          (List.Assoc.find [ _amzn; _c ] symbol ~equal:String.equal)
          ~f:List.last)
      ~skip_position_ids:String.Set.empty ~current_date:_as_of
    |> List.map ~f:(fun (t : Trading_strategy.Position.transition) ->
        t.position_id)
  in
  assert_that
    [ exited ~armed:false; exited ~armed:true ]
    (elements_are
       [ elements_are [ equal_to "C" ]; elements_are [ equal_to "AMZN" ] ])

let test_unarmed_reader_has_no_divisor _ =
  assert_that
    ( Bar_reader.split_divisor_for (_reader ~armed:false) ~symbol:"AMZN",
      Option.map
        (Bar_reader.split_divisor_for (_reader ~armed:true) ~symbol:"AMZN")
        ~f:(fun f -> f _as_of) )
    (pair is_none (is_some_and (float_equal 20.0)))

let suite =
  "liquidity_true_dollars"
  >::: [
         "divisor applies per bar" >:: test_divisor_applies_per_bar;
         "entry gate flips on true dollars"
         >:: test_entry_gate_flips_on_true_dollars;
         "short borrow gate reads true dollars"
         >:: test_short_borrow_gate_reads_true_dollars;
         "hold exit flips on true dollars (#3301)"
         >:: test_hold_exit_flips_on_true_dollars;
         "unarmed reader has no divisor" >:: test_unarmed_reader_has_no_divisor;
       ]

let () = run_test_tt_main suite
