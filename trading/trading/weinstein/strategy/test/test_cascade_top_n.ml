(** {!Cascade_trace.with_top_n}: the join that turns a Friday's cascade rows and
    its entry walk into the [candidates.sexp] top-N view.

    One real screen over three names with a one-slot cap: HIGH (Strong sector)
    is kept, LOW (Neutral, ten points lower) is cut, WEAK (Weak sector) drops at
    the sector gate. The stop check is a stub answering by ticker, so the test
    pins the join, not the check (that is [test_walk_report.ml]). Pinned: both
    cleared rows get their rank in the cap's order and nothing else does; the
    kept row gets its walk outcome (funded with its distance, a [Stop_too_wide]
    skip with the gate's distance, a held skip with none, or not reached); the
    cut row gets the shadow. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module AR = Audit_recorder

let _as_of = Date.of_string "2024-06-14"

(* The screener tests' rising weekly breakout with a volume spike. *)
let _weekly_bars =
  let base = Date.of_string "2020-01-06" in
  List.init 35 ~f:(fun i ->
      let close = 50.0 +. (Float.of_int i *. (50.0 /. 34.0)) in
      {
        Types.Daily_price.date = Date.add_days base (i * 7);
        open_price = close;
        high_price = close *. 1.02;
        low_price = close *. 0.98;
        close_price = close;
        adjusted_close = close;
        volume = (if i = 31 then 3000 else 1000);
        active_through = None;
      })

let _name ticker rating : Stock_analysis.t * Screener.sector_context =
  ( Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:_weekly_bars ~benchmark_bars:[]
      ~prior_stage:(Some (Weinstein_types.Stage1 { weeks_in_base = 10 }))
      ~as_of_date:_as_of,
    {
      sector_name = ticker ^ "-sector";
      rating;
      stage = Weinstein_types.Stage2 { weeks_advancing = 5; late = false };
    } )

let _config = { Screener.default_config with max_buy_candidates = 1 }

(* The screen's cascade input, its rows and its kept candidate. *)
let _screen () =
  let names =
    [
      _name "HIGH" Screener.Strong;
      _name "LOW" Screener.Neutral;
      _name "WEAK" Screener.Weak;
    ]
  in
  let sector_map = Hashtbl.create (module String) in
  List.iter names ~f:(fun ((a : Stock_analysis.t), s) ->
      Hashtbl.set sector_map ~key:a.ticker ~data:s);
  let candidates = ref [] in
  let result =
    Screener.screen_with_cooldown ~config:_config
      ~macro_trend:Weinstein_types.Bullish ~sector_map
      ~stocks:(List.map names ~f:fst) ~held_tickers:[] ~as_of:_as_of
      ~last_stop_out_dates:[]
      ~on_candidates:(fun cs -> candidates := cs)
      ()
  in
  ( !candidates,
    Cascade_trace.of_screen ~config:_config ~macro_trend:Weinstein_types.Bullish
      ~candidates:!candidates ~result,
    List.hd_exn result.buy_candidates )

(* A stop check reporting [decision] at [distance]. *)
let _check decision distance : Entry_stop_check.t =
  {
    decision_bar = None;
    effective_entry = 100.0;
    stops =
      {
        placed =
          Weinstein_stops.compute_initial_stop
            ~config:Weinstein_stops.default_config ~side:Trading_base.Types.Long
            ~reference_level:90.0;
        placed_kind = Support_floor;
        placed_basis = Flag_off;
        placed_distance_pct = distance;
        gate_kind = Support_floor;
        gate_distance_pct = distance;
      };
    max_stop_distance_pct = 0.15;
    decision;
  }

(* One row as [(ticker, Some (rank, verdict tag, distance))]. *)
let _summary (d : AR.cascade_drop) =
  let view (v : AR.Top_n.t) =
    match v.verdict with
    | Walked { outcome = Placed; stop_distance_pct } ->
        (v.rank, "funded", stop_distance_pct)
    | Walked { outcome = Skipped Stop_too_wide; stop_distance_pct } ->
        (v.rank, "skipped too wide", stop_distance_pct)
    | Walked { outcome = Skipped _; stop_distance_pct } ->
        (v.rank, "skipped other", stop_distance_pct)
    | Not_reached -> (v.rank, "not reached", None)
    | Shadow (Buyable d) -> (v.rank, "shadow buyable", Some d)
    | Shadow _ -> (v.rank, "shadow other", None)
  in
  (d.outcome.ticker, Option.map d.top_n ~f:view)

(* [with_top_n] with HIGH's walk [outcome] (none: the walk never saw it) and
   HIGH's stop check; LOW's check says buyable at 9%. *)
let _rows ~outcome ~high_check =
  let candidates, drops, high = _screen () in
  let report : Entry_walk.walk_report =
    {
      long_cash_left_pct = 0.5;
      held = String.Set.empty;
      stop_check =
        (fun (c : Screener.scored_candidate) ->
          if String.equal c.ticker "HIGH" then high_check
          else _check (Width Stop_width_mode.Admit) 0.09);
    }
  in
  let decisions =
    Option.value_map outcome ~default:[] ~f:(fun outcome ->
        [ { AR.ranked = high; outcome } ])
  in
  Cascade_trace.with_top_n ~config:_config ~date:_as_of ~candidates ~decisions
    ~report drops
  |> List.map ~f:_summary

(* LOW is rank 2 with a buyable shadow; WEAK carries no top-N view. *)
let _with_high high =
  [
    ("HIGH", Some high);
    ("LOW", Some (2, "shadow buyable", Some 0.09));
    ("WEAK", None);
  ]

(** Rank on both row kinds, and a funded kept row with its stop distance. *)
let test_rank_and_funded_walk _ =
  assert_that
    (_rows ~outcome:(Some AR.Placed)
       ~high_check:(_check (Width Stop_width_mode.Admit) 0.06))
    (equal_to (_with_high (1, "funded", Some 0.06)))

(** A kept row the walk skipped as [Stop_too_wide] carries the skip and the
    distance the width gate measured. *)
let test_stop_too_wide_skip_carries_its_distance _ =
  assert_that
    (_rows ~outcome:(Some (AR.Skipped Stop_too_wide))
       ~high_check:(_check (Width Stop_width_mode.Drop) 0.22))
    (equal_to (_with_high (1, "skipped too wide", Some 0.22)))

(** A skip the walk takes before building any stop records no distance. *)
let test_held_skip_carries_no_distance _ =
  assert_that
    (_rows ~outcome:(Some (AR.Skipped Already_held))
       ~high_check:(_check (Width Stop_width_mode.Admit) 0.06))
    (equal_to (_with_high (1, "skipped other", None)))

(** A kept row the walk never classified (an entry-assembly gate removed it) is
    [Not_reached]. *)
let test_unwalked_kept_row_is_not_reached _ =
  assert_that
    (_rows ~outcome:None
       ~high_check:(_check (Width Stop_width_mode.Admit) 0.06))
    (equal_to (_with_high (1, "not reached", None)))

let () =
  run_test_tt_main
    ("cascade_top_n"
    >::: [
           "rank on both row kinds; funded walk" >:: test_rank_and_funded_walk;
           "Stop_too_wide skip carries its distance"
           >:: test_stop_too_wide_skip_carries_its_distance;
           "held skip carries no distance"
           >:: test_held_skip_carries_no_distance;
           "unwalked kept row is not reached"
           >:: test_unwalked_kept_row_is_not_reached;
         ])
