(** [Screener.index_stage_veto_blocks_longs] — the default-off long-admission
    veto on a primary index in Stage 4.

    Book §2.1 ("Resolved 2026-09-16 — veto or vote?"): Ch. 8 makes the index's
    Stage-4 breakdown below the 30-week MA an unconditional suspension of new
    buying — "Suspend buying even if you see a few stocks breaking out on their
    charts" — not one weighted vote in the Weight-of-the-Evidence composite. A
    Stage-3 index top is caution only, so it is deliberately not vetoed.

    Two levels are pinned here:
    - the pure gate {!Screener.longs_admitted_by_index_stage} over its whole
      input surface (flag × stage), and
    - the cascade: [screen_with_cooldown ?index_stage] on a tape whose
      [macro_trend] is [Bullish], which is the case that matters — the composite
      reading [Bullish] while the index itself is in Stage 4 is exactly what the
      2022 cohort did. *)

open OUnit2
open Core
open Matchers
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

let _as_of = Date.of_string "2024-01-01"

let _bar ~volume date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.02;
    low_price = adjusted_close *. 0.98;
    close_price = adjusted_close;
    adjusted_close;
    volume;
    active_through = None;
  }

(** A Stage-1 base lifting into a volume-confirmed breakout — the standard
    admitted-long fixture used across [test_screener.ml]. *)
let _breakout_bars ~n =
  let base = Date.of_string "2020-01-06" in
  let step = (100.0 -. 50.0) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let volume = if i = 31 then 3000 else 1000 in
      _bar ~volume
        (Date.to_string (Date.add_days base (i * 7)))
        (50.0 +. (Float.of_int i *. step)))

let _breakout_stock ticker =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
    ~bars:(_breakout_bars ~n:35) ~benchmark_bars:[]
    ~prior_stage:(Some (Stage1 { weeks_in_base = 10 }))
    ~as_of_date:_as_of

let _empty_sector_map () = Hashtbl.create (module String)

let _config veto =
  { Screener.default_config with index_stage_veto_blocks_longs = veto }

(** The whole stage surface, [None] included. Exactly one cell of
    [flag × this list] may be rejecting. *)
let _all_index_stages : stage option list =
  [
    None;
    Some (Stage1 { weeks_in_base = 12 });
    Some (Stage2 { weeks_advancing = 8; late = false });
    Some (Stage2 { weeks_advancing = 40; late = true });
    Some (Stage3 { weeks_topping = 6 });
    Some (Stage4 { weeks_declining = 9 });
  ]

(* ------------------------------------------------------------------ *)
(* The pure gate                                                        *)
(* ------------------------------------------------------------------ *)

let _admits ~flag stage =
  Screener.longs_admitted_by_index_stage ~index_stage_veto_blocks_longs:flag
    stage

(** The gate over its {b whole} input surface: every (flag × stage) pair, 12
    booleans. Exhaustive rather than sampled because the gate's entire claim is
    a separation — the flag removes [Stage4] and nothing else, and it can only
    ever remove. Rows are [flag = false] then [flag = true]; columns are
    {!_all_index_stages}, so the single [false] is the last cell of the second
    row.

    EFFECTIVENESS-PIN: broadening the match to [Stage3] (the caution-only case
    the book does {e not} veto), narrowing it so [None] rejects, or dropping the
    [not] each turns a cell of this grid. *)
let test_gate_truth_table_over_every_flag_and_stage _ =
  assert_that
    (List.map [ false; true ] ~f:(fun flag ->
         List.map _all_index_stages ~f:(_admits ~flag)))
    (elements_are
       [
         equal_to [ true; true; true; true; true; true ];
         equal_to [ true; true; true; true; true; false ];
       ])

(** [weeks_declining] is not read: every Stage-4 index is vetoed, including the
    transition week itself ([weeks_declining = 0]), which is how the book's "3→4
    or 4" case is covered — [Stage.result.stage] already reports [Stage4] on the
    week the breakdown happens. *)
let test_every_stage4_is_vetoed_regardless_of_weeks_declining _ =
  assert_that
    (List.map [ 0; 1; 52 ] ~f:(fun weeks_declining ->
         _admits ~flag:true (Some (Stage4 { weeks_declining }))))
    (elements_are [ equal_to false; equal_to false; equal_to false ])

(* ------------------------------------------------------------------ *)
(* The cascade                                                          *)
(* ------------------------------------------------------------------ *)

let _buys_in ?index_stage ~veto () =
  (Screener.screen_with_cooldown ?index_stage ~config:(_config veto)
     ~macro_trend:Bullish ~sector_map:(_empty_sector_map ())
     ~stocks:[ _breakout_stock "AAPL" ]
     ~held_tickers:[] ~as_of:_as_of ~last_stop_out_dates:[] ())
    .Screener.buy_candidates
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.Screener.ticker)

(** The headline criterion: a [Bullish] macro trend and a candidate the cascade
    admits, and arming the flag under a Stage-4 index yields zero buys. Both
    arms hold the same tape and the same candidate — only the flag moves.

    EFFECTIVENESS-PIN: dropping [~index_stage_admits]/[_longs_admitted]'s veto
    conjunct from [_evaluate_longs], or failing to thread [?index_stage] through
    [screen_with_cooldown], leaves the second arm non-empty. *)
let test_stage4_index_blocks_every_buy_when_armed _ =
  assert_that
    [
      _buys_in ~index_stage:(Stage4 { weeks_declining = 9 }) ~veto:false ();
      _buys_in ~index_stage:(Stage4 { weeks_declining = 9 }) ~veto:true ();
    ]
    (elements_are [ elements_are [ equal_to "AAPL" ]; is_empty ])

(** Narrowness: with the flag ON, every non-Stage-4 index still admits the same
    buy list. [Stage3] is the load-bearing one — the book calls an index top
    caution, not a suspension, so a veto that fired there would be unfaithful.
*)
let test_only_stage4_is_vetoed_through_the_cascade _ =
  assert_that
    (List.map
       [
         Stage1 { weeks_in_base = 12 };
         Stage2 { weeks_advancing = 8; late = false };
         Stage3 { weeks_topping = 6 };
       ]
       ~f:(fun index_stage -> _buys_in ~index_stage ~veto:true ()))
    (elements_are
       [ equal_to [ "AAPL" ]; equal_to [ "AAPL" ]; equal_to [ "AAPL" ] ])

(** R1 ([.claude/rules/experiment-flag-discipline.md]): the flag off is the
    historical cascade bit-equally, and so is the flag on with no [?index_stage]
    supplied. Pinned as three identical buy lists against the pre-veto call
    shape ({!Screener.screen}, which cannot pass an index stage at all). *)
let test_the_default_and_the_absent_argument_are_both_no_ops _ =
  let baseline =
    (Screener.screen ~config:Screener.default_config ~macro_trend:Bullish
       ~sector_map:(_empty_sector_map ())
       ~stocks:[ _breakout_stock "AAPL" ]
       ~held_tickers:[])
      .Screener.buy_candidates
    |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.Screener.ticker)
  in
  assert_that
    [
      _buys_in ~index_stage:(Stage4 { weeks_declining = 9 }) ~veto:false ();
      _buys_in ~veto:true ();
      baseline;
    ]
    (elements_are
       [ equal_to [ "AAPL" ]; equal_to [ "AAPL" ]; equal_to [ "AAPL" ] ])

(** The shipped screener default is the no-op (R1), asserted on
    [Screener.default_config] rather than a literal — a default flip has to move
    this. *)
let test_the_shipped_screener_default_is_off _ =
  assert_that Screener.default_config.Screener.index_stage_veto_blocks_longs
    (equal_to false)

let suite =
  "index_stage_veto_gate"
  >::: [
         "gate truth table over every flag and stage"
         >:: test_gate_truth_table_over_every_flag_and_stage;
         "every Stage4 is vetoed regardless of weeks_declining"
         >:: test_every_stage4_is_vetoed_regardless_of_weeks_declining;
         "a Stage4 index blocks every buy when armed"
         >:: test_stage4_index_blocks_every_buy_when_armed;
         "only Stage4 is vetoed through the cascade"
         >:: test_only_stage4_is_vetoed_through_the_cascade;
         "the default and the absent argument are both no-ops"
         >:: test_the_default_and_the_absent_argument_are_both_no_ops;
         "the shipped screener default is off"
         >:: test_the_shipped_screener_default_is_off;
       ]

let () = run_test_tt_main suite
