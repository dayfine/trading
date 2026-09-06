(** Acceptance test for the breadth-direction read, on real data.

    Runs against the committed daily breadth series
    ([trading/test_data/breadth/synthetic_breadth_daily.csv], computed over
    per-year point-in-time top-3000 universes) and real cached [GSPC.INDX] bars,
    and asserts the states the 27-year study reports
    ([dev/experiments/stop-width-cadence-surface-2026-09-05/README.md] §"Breadth
    state across 27 years").

    Three claims:

    - {b The series reads Deteriorating down and Recovering up.} The COVID crash
      and rebound are the two cohorts whose realized P&L diverged most sharply,
      and both sit below the same participation threshold — a rule keyed on the
      level alone could not tell them apart. Checked on the real cache as the
      study's own date -> state table, asserted date by date rather than as an
      existence count over the two windows.
    - {b The read is live end to end.} Driving {!Macro.analyze_with_callbacks}
      Friday by Friday over 2017-2026 produces both extra states.
    - {b Disabled is the identity.} With the default config the projection
      round-trips on every Friday of a multi-year window even though a breadth
      series is wired — the R1 default-off contract as a property rather than a
      golden.

    {b Why claim 1 is not asserted through [Macro.analyze_with_callbacks].}
    [Breadth_direction]'s first rule short-circuits a [Bearish] tape to
    [Bearish_breadth], and this test's macro reading — GSPC alone, with no A-D
    bars and no global indices — turns Bearish on 2020-02-28 and stays there
    through the crash, so the end-to-end path reports [Bearish_breadth] on every
    Friday of the sell-off window. The production run the study measured had the
    full indicator set and read Bullish through 2020-03-06, then Neutral into
    May, which is why its entries landed in the Deteriorating and Recovering
    cohorts at all. Claim 1 therefore drives the real cache with
    [~trend:Neutral] — the tape the study saw — rather than reconstructing that
    whole indicator set here. Claim 2 covers the wiring the short-circuit hides.

    Skipped when the cached breadth CSV is absent (the data directory resolves
    via [TRADING_DATA_DIR], which CI points at [trading/test_data]). *)

open Core
open OUnit2
open Matchers
open Weinstein_types

let _data_dir = Fpath.to_string (Data_path.default_data_dir ())
let _on = { Breadth_direction.default_config with enabled = true }
let _date = Date.of_string

(** Every Friday in [start, end_] inclusive. *)
let _fridays ~start ~end_ =
  let rec walk d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let acc = match Date.day_of_week d with Fri -> d :: acc | _ -> acc in
      walk (Date.add_days d 1) acc
  in
  walk start []

let _series () =
  match Breadth_bars.load ~data_dir:_data_dir with
  | [] -> None
  | bars -> Some (Breadth_series_cache.of_daily_bars bars)

let _skip_unless = function
  | Some x -> x
  | None ->
      skip_if true "no cached breadth series";
      assert false

(* ------------------------------------------------------------------ *)
(* Claim 1 — the real series reads the study's two cohorts             *)
(* ------------------------------------------------------------------ *)

(** The breadth state at [as_of] on a [Neutral] tape, sampled from the real
    cache exactly as {!Macro.analyze_with_callbacks} samples it: offsets 0 and
    [lookback_weeks]. *)
let _series_state series ~as_of =
  let pct_above, new_lows = Breadth_series_cache.callbacks_at series ~as_of in
  let back = _on.lookback_weeks in
  Breadth_direction.classify ~config:_on ~trend:Neutral
    ~pct_above:(pct_above ~week_offset:0)
    ~pct_above_prior:(pct_above ~week_offset:back)
    ~nl_pct:(new_lows ~week_offset:0)
    ~nl_pct_prior:(new_lows ~week_offset:back)

(** The study's date -> state table, asserted as the table it is rather than as
    an existence count over a window: each listed date maps to the state the
    27-year study reports for it, in order. An existence count would survive a
    rule that labelled only one day of each window correctly. *)
let test_study_date_to_state_table _ =
  let series = _skip_unless (_series ()) in
  let states =
    List.map
      [
        "2020-02-28";
        "2020-03-06";
        "2020-03-13";
        "2020-04-09";
        "2020-04-17";
        "2020-04-24";
        "2020-04-30";
      ] ~f:(fun d -> _series_state series ~as_of:(_date d))
  in
  assert_that states
    (elements_are
       [
         equal_to Deteriorating;
         equal_to Deteriorating;
         equal_to Deteriorating;
         equal_to Recovering;
         equal_to Recovering;
         equal_to Recovering;
         equal_to Recovering;
       ])

(** The same level, opposite direction, opposite label — the property a
    level-only threshold cannot express. Participation is below the 45% weak
    threshold across both windows. *)
let test_same_level_opposite_direction_opposite_state _ =
  let series = _skip_unless (_series ()) in
  let pct_above_on as_of =
    let pct_above, _ = Breadth_series_cache.callbacks_at series ~as_of in
    pct_above ~week_offset:0
  in
  assert_that
    [ pct_above_on (_date "2020-03-13"); pct_above_on (_date "2020-04-17") ]
    (elements_are
       [
         is_some_and (lt (module Float_ord) _on.weak_pct_above);
         is_some_and (lt (module Float_ord) _on.weak_pct_above);
       ])

(* ------------------------------------------------------------------ *)
(* Claims 2 and 3 — the end-to-end macro path                          *)
(* ------------------------------------------------------------------ *)

(* The Stage classification needs a long weekly warmup before the window under
   test. GSPC coverage in [trading/test_data] begins 2009-01-02. *)
let _bars_from = _date "2012-01-01"

(** The macro reading at [as_of]: index bars sliced to [as_of] (so the Stage
    classification sees only the past), breadth sliced by
    {!Breadth_series_cache}'s own [as_of] cutoff. *)
let _state_at ~config ~series ~weekly ~as_of =
  let index_bars =
    List.filter weekly ~f:(fun (b : Types.Daily_price.t) ->
        Date.( <= ) b.date as_of)
  in
  let callbacks =
    Macro.callbacks_from_bars ~config ~index_bars ~ad_bars:[]
      ~global_index_bars:[]
  in
  Macro.analyze_with_callbacks ~config
    ~callbacks:(Macro.with_breadth callbacks series ~as_of)
    ~prior_stage:None ~prior:None

let _states_over ~config ~from_date ~to_date =
  let series = _skip_unless (_series ()) in
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX" ~start_date:_bars_from
      ~end_date:to_date
  in
  _fridays ~start:from_date ~end_:to_date
  |> List.map ~f:(fun as_of -> _state_at ~config ~series ~weekly ~as_of)

let _enabled_config = { Macro.default_config with breadth_direction = _on }

let _count_end_to_end ~from_date ~to_date target =
  _states_over ~config:_enabled_config ~from_date ~to_date
  |> List.count ~f:(fun (r : Macro.result) ->
      equal_breadth_state r.breadth_state target)

(** Liveness through the whole macro path, not just the cache: the October 2018
    breadth break reads Deteriorating on a tape the gate calls Neutral. *)
let test_end_to_end_reports_deteriorating _ =
  assert_that
    (_count_end_to_end ~from_date:(_date "2018-10-01")
       ~to_date:(_date "2018-10-31") Deteriorating)
    (gt (module Int_ord) 0)

(** The other half of the liveness check: June 2020 reads Recovering. *)
let test_end_to_end_reports_recovering _ =
  assert_that
    (_count_end_to_end ~from_date:(_date "2020-06-01")
       ~to_date:(_date "2020-06-30") Recovering)
    (gt (module Int_ord) 0)

(** R1: with the default (disabled) config,
    [market_trend_of_breadth_state breadth_state = trend] on every Friday of a
    multi-year window — even though a breadth series is wired and the same
    window contains Fridays the enabled read labels Deteriorating and
    Recovering. *)
let test_disabled_projection_round_trips _ =
  let mismatches =
    _states_over ~config:Macro.default_config ~from_date:(_date "2018-01-01")
      ~to_date:(_date "2020-12-31")
    |> List.count ~f:(fun (r : Macro.result) ->
        not
          (equal_market_trend
             (market_trend_of_breadth_state r.breadth_state)
             r.trend))
  in
  assert_that mismatches (equal_to 0)

let suite =
  "breadth_direction_e2e"
  >::: [
         "the real series reproduces the study's date -> state table"
         >:: test_study_date_to_state_table;
         "both windows sit below the same weak-participation threshold"
         >:: test_same_level_opposite_direction_opposite_state;
         "end to end: October 2018 reports Deteriorating"
         >:: test_end_to_end_reports_deteriorating;
         "end to end: June 2020 reports Recovering"
         >:: test_end_to_end_reports_recovering;
         "disabled: the projection round-trips on every Friday 2018-2020"
         >:: test_disabled_projection_round_trips;
       ]

let () = run_test_tt_main suite
