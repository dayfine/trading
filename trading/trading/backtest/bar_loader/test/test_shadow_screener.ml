(** Tests for Bar_loader.Shadow_screener. *)

open OUnit2
open Core
open Matchers
module Shadow_screener = Bar_loader.Shadow_screener
module Summary_compute = Bar_loader.Summary_compute

let _as_of = Date.create_exn ~y:2023 ~m:Dec ~d:29

let _mk_summary ?(ma_30w = 100.0) ?(atr_14 = 1.0) ?(rs_line = 1.0)
    ?(stage : Weinstein_types.stage = Stage1 { weeks_in_base = 8 }) () :
    Summary_compute.summary_values =
  { ma_30w; atr_14; rs_line; stage; as_of = _as_of }

let _mk_sector_map ~entries =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (ticker, ctx) ->
      Hashtbl.set tbl ~key:ticker ~data:ctx);
  tbl

let _strong_sector : Screener.sector_context =
  {
    sector_name = "Tech";
    rating = Strong;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

let test_synthesize_rising_stage_maps_to_positive_rs _ =
  let summary = _mk_summary ~rs_line:1.2 () in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.rs
    (is_some_and
       (field
          (fun (r : Rs.result) -> r.trend)
          (equal_to Weinstein_types.Positive_rising)))

let test_synthesize_below_zero_line_maps_to_negative_declining _ =
  let summary = _mk_summary ~rs_line:0.8 () in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.rs
    (is_some_and
       (field
          (fun (r : Rs.result) -> r.trend)
          (equal_to Weinstein_types.Negative_declining)))

let test_synthesize_stage2_sets_ma_direction_rising _ =
  let summary =
    _mk_summary ~stage:(Stage2 { weeks_advancing = 3; late = false }) ()
  in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.stage.ma_direction (equal_to Weinstein_types.Rising)

let test_synthesize_stage4_sets_ma_direction_declining _ =
  let summary = _mk_summary ~stage:(Stage4 { weeks_declining = 2 }) () in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.stage.ma_direction (equal_to Weinstein_types.Declining)

let test_synthesize_stage1_and_stage3_use_flat _ =
  let s1 =
    Shadow_screener.synthesize_analysis
      ~summary:(_mk_summary ~stage:(Stage1 { weeks_in_base = 8 }) ())
      ~ticker:"S1" ~prior_stage:None ~as_of:_as_of
  in
  let s3 =
    Shadow_screener.synthesize_analysis
      ~summary:(_mk_summary ~stage:(Stage3 { weeks_topping = 2 }) ())
      ~ticker:"S3" ~prior_stage:None ~as_of:_as_of
  in
  assert_that s1.stage.ma_direction (equal_to Weinstein_types.Flat);
  assert_that s3.stage.ma_direction (equal_to Weinstein_types.Flat)

let test_synthesize_transition_detected_when_prior_stage_differs _ =
  let summary =
    _mk_summary ~stage:(Stage2 { weeks_advancing = 1; late = false }) ()
  in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:(Some (Weinstein_types.Stage1 { weeks_in_base = 10 }))
      ~as_of:_as_of
  in
  assert_that analysis.stage.transition
    (is_some_and
       (equal_to
          ( (Weinstein_types.Stage1 { weeks_in_base = 10 }
              : Weinstein_types.stage),
            (Weinstein_types.Stage2 { weeks_advancing = 1; late = false }
              : Weinstein_types.stage) )))

let test_synthesize_no_transition_when_prior_matches _ =
  let summary = _mk_summary ~stage:(Stage1 { weeks_in_base = 8 }) () in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:(Some (Weinstein_types.Stage1 { weeks_in_base = 8 }))
      ~as_of:_as_of
  in
  assert_that analysis.stage.transition is_none

let test_synthesize_stage1_has_no_volume_and_no_resistance _ =
  let summary = _mk_summary () in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.volume is_none;
  assert_that analysis.resistance is_none;
  assert_that analysis.breakout_price is_none

let test_synthesize_stage2_gets_adequate_volume_floor _ =
  let summary =
    _mk_summary ~stage:(Stage2 { weeks_advancing = 1; late = false }) ()
  in
  let analysis =
    Shadow_screener.synthesize_analysis ~summary ~ticker:"STOCK"
      ~prior_stage:None ~as_of:_as_of
  in
  assert_that analysis.volume
    (is_some_and
       (field
          (fun (v : Volume.result) -> v.confirmation)
          (equal_to (Weinstein_types.Adequate 1.5))));
  assert_that analysis.resistance is_none;
  assert_that analysis.breakout_price is_none

let test_screen_empty_summaries_returns_empty_result _ =
  let prior_stages = Hashtbl.create (module String) in
  let result =
    Shadow_screener.screen ~summaries:[] ~config:Screener.default_config
      ~macro_trend:Bullish
      ~sector_map:(_mk_sector_map ~entries:[])
      ~prior_stages ~held_tickers:[] ~as_of:_as_of
  in
  assert_that result.buy_candidates (size_is 0);
  assert_that result.short_candidates (size_is 0);
  assert_that result.watchlist (size_is 0);
  assert_that result.macro_trend (equal_to Weinstein_types.Bullish)

let test_screen_bearish_macro_produces_no_buys _ =
  let summaries =
    [
      ( "STOCK",
        _mk_summary
          ~stage:(Stage2 { weeks_advancing = 2; late = false })
          ~rs_line:1.2 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("STOCK", _strong_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"STOCK"
    ~data:(Weinstein_types.Stage1 { weeks_in_base = 10 });
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bearish ~sector_map ~prior_stages ~held_tickers:[]
      ~as_of:_as_of
  in
  assert_that result.buy_candidates (size_is 0)

let test_screen_stage2_transition_produces_buy_candidate _ =
  let summaries =
    [
      ( "STOCK",
        _mk_summary
          ~stage:(Stage2 { weeks_advancing = 1; late = false })
          ~rs_line:1.2 ~ma_30w:100.0 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("STOCK", _strong_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"STOCK"
    ~data:(Weinstein_types.Stage1 { weeks_in_base = 10 });
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bullish ~sector_map ~prior_stages ~held_tickers:[]
      ~as_of:_as_of
  in
  assert_that result.buy_candidates
    (elements_are
       [
         all_of
           [
             field
               (fun (c : Screener.scored_candidate) -> c.ticker)
               (equal_to "STOCK");
             field
               (fun (c : Screener.scored_candidate) -> c.side)
               (equal_to Trading_base.Types.Long);
           ];
       ])

let test_screen_updates_prior_stages_in_place _ =
  let summaries =
    [
      ( "STOCK",
        _mk_summary ~stage:(Stage2 { weeks_advancing = 1; late = false }) () );
    ]
  in
  let prior_stages = Hashtbl.create (module String) in
  let _ =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bullish
      ~sector_map:(_mk_sector_map ~entries:[])
      ~prior_stages ~held_tickers:[] ~as_of:_as_of
  in
  assert_that
    (Hashtbl.find prior_stages "STOCK")
    (is_some_and
       (equal_to (Weinstein_types.Stage2 { weeks_advancing = 1; late = false })))

let test_screen_held_tickers_excluded _ =
  let summaries =
    [
      ( "HELD",
        _mk_summary
          ~stage:(Stage2 { weeks_advancing = 1; late = false })
          ~rs_line:1.3 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("HELD", _strong_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"HELD"
    ~data:(Weinstein_types.Stage1 { weeks_in_base = 10 });
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bullish ~sector_map ~prior_stages ~held_tickers:[ "HELD" ]
      ~as_of:_as_of
  in
  assert_that result.buy_candidates (size_is 0)

let test_screen_stage4_transition_produces_short_candidate _ =
  let weak_sector : Screener.sector_context =
    {
      sector_name = "Tech";
      rating = Weak;
      stage = Stage4 { weeks_declining = 2 };
    }
  in
  let summaries =
    [
      ( "STOCK",
        _mk_summary ~stage:(Stage4 { weeks_declining = 1 }) ~rs_line:0.7 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("STOCK", weak_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"STOCK"
    ~data:(Weinstein_types.Stage3 { weeks_topping = 3 });
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Neutral ~sector_map ~prior_stages ~held_tickers:[]
      ~as_of:_as_of
  in
  assert_that result.short_candidates
    (elements_are
       [
         all_of
           [
             field
               (fun (c : Screener.scored_candidate) -> c.ticker)
               (equal_to "STOCK");
             field
               (fun (c : Screener.scored_candidate) -> c.side)
               (equal_to Trading_base.Types.Short);
           ];
       ])

let test_screen_preserves_synthesis_on_analysis_field _ =
  let summaries =
    [
      ( "STOCK",
        _mk_summary
          ~stage:(Stage2 { weeks_advancing = 1; late = false })
          ~rs_line:1.2 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("STOCK", _strong_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"STOCK"
    ~data:(Weinstein_types.Stage1 { weeks_in_base = 10 });
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bullish ~sector_map ~prior_stages ~held_tickers:[]
      ~as_of:_as_of
  in
  assert_that result.buy_candidates
    (elements_are
       [
         field
           (fun (c : Screener.scored_candidate) -> c.analysis)
           (all_of
              [
                field
                  (fun (a : Stock_analysis.t) -> a.volume)
                  (is_some_and
                     (field
                        (fun (v : Volume.result) -> v.confirmation)
                        (equal_to (Weinstein_types.Adequate 1.5))));
                field (fun (a : Stock_analysis.t) -> a.resistance) is_none;
                field (fun (a : Stock_analysis.t) -> a.breakout_price) is_none;
              ]);
       ])

let test_screen_rejects_mid_stage2_without_prior_stage1 _ =
  let summaries =
    [
      ( "STOCK",
        _mk_summary
          ~stage:(Stage2 { weeks_advancing = 10; late = false })
          ~rs_line:1.2 () );
    ]
  in
  let sector_map = _mk_sector_map ~entries:[ ("STOCK", _strong_sector) ] in
  let prior_stages = Hashtbl.create (module String) in
  let result =
    Shadow_screener.screen ~summaries ~config:Screener.default_config
      ~macro_trend:Bullish ~sector_map ~prior_stages ~held_tickers:[]
      ~as_of:_as_of
  in
  assert_that result.buy_candidates (size_is 0)

let suite =
  "Shadow_screener"
  >::: [
         "synthesize_rising_stage_maps_to_positive_rs"
         >:: test_synthesize_rising_stage_maps_to_positive_rs;
         "synthesize_below_zero_line_maps_to_negative_declining"
         >:: test_synthesize_below_zero_line_maps_to_negative_declining;
         "synthesize_stage2_sets_ma_direction_rising"
         >:: test_synthesize_stage2_sets_ma_direction_rising;
         "synthesize_stage4_sets_ma_direction_declining"
         >:: test_synthesize_stage4_sets_ma_direction_declining;
         "synthesize_stage1_and_stage3_use_flat"
         >:: test_synthesize_stage1_and_stage3_use_flat;
         "synthesize_transition_detected_when_prior_stage_differs"
         >:: test_synthesize_transition_detected_when_prior_stage_differs;
         "synthesize_no_transition_when_prior_matches"
         >:: test_synthesize_no_transition_when_prior_matches;
         "synthesize_stage1_has_no_volume_and_no_resistance"
         >:: test_synthesize_stage1_has_no_volume_and_no_resistance;
         "synthesize_stage2_gets_adequate_volume_floor"
         >:: test_synthesize_stage2_gets_adequate_volume_floor;
         "screen_empty_summaries_returns_empty_result"
         >:: test_screen_empty_summaries_returns_empty_result;
         "screen_bearish_macro_produces_no_buys"
         >:: test_screen_bearish_macro_produces_no_buys;
         "screen_stage2_transition_produces_buy_candidate"
         >:: test_screen_stage2_transition_produces_buy_candidate;
         "screen_updates_prior_stages_in_place"
         >:: test_screen_updates_prior_stages_in_place;
         "screen_held_tickers_excluded" >:: test_screen_held_tickers_excluded;
         "screen_stage4_transition_produces_short_candidate"
         >:: test_screen_stage4_transition_produces_short_candidate;
         "screen_preserves_synthesis_on_analysis_field"
         >:: test_screen_preserves_synthesis_on_analysis_field;
         "screen_rejects_mid_stage2_without_prior_stage1"
         >:: test_screen_rejects_mid_stage2_without_prior_stage1;
       ]

let () = run_test_tt_main suite
