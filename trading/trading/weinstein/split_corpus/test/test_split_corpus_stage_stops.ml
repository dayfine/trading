(** Split corpus x stage classifier and stop machine (issue #2973).

    Two basis consumers, run over every corpus entry. Each assertion is a
    relative quantity that must not jump when the issuer splits:

    - {b Stage classifier / 30-week MA.} The classifier's close/MA (adjusted
      close over its own MA, the pair it decides Stage 2 on) moves across each
      split week by less than half the split's own log ratio. A classifier fed
      RAW closes would jump by about the whole ratio (4:1 is log 4 = 1.39; the
      corpus's week-over-week moves stay under 0.2), so the bound separates the
      two for the smallest ratio here (C's 4:3, log = 0.29).
    - {b Initial stop across the ex-date.} The stop placed the day before the
      split and rescaled by [Stop_split_adjust.scale] (what
      [Stops_split_runner] does) reads the ex-date bar exactly as the unscaled
      stop reads that bar restated in pre-split dollars: same hit decision,
      same stop distance %.
    - {b Trailing ratchet over the window.} The stop machine driven weekly in
      RAW dollars (scaled at each ex-date) and in the window's final basis
      (every pre-split price divided by the pending split product) keeps the
      same stop, relative to price, all window long. The MA fed to
      [Weinstein_stops.update] is the classifier's adjusted MA restated into
      each bar's raw basis ([ma /. adjustment_factor bar]) — NOTE the
      production [Stops_runner] does not do this restatement today (it passes
      the adjusted MA beside a raw bar); that is reported on issue #2973 as a
      decision-level finding, not fixed here. This test pins the machine's own
      basis-equivariance, which any fix will rely on. *)

open OUnit2
open Core
open Matchers

let _entries =
  [
    "AAPL-2014-06-09";
    "AAPL-2020-08-31";
    "C-1996-05-28";
    "GE-2021-08-02";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

let _stage_config = Stage.default_config
let _stops_config = Weinstein_stops.default_config
let _long = Trading_base.Types.Long

(* Initial-stop fallback when no support floor qualifies: 8% below entry, the
   value the strategy tests use. *)
let _fallback_buffer = 0.92

(* The trailing paths may differ only through the stop machine's absolute
   round-number nudge (an eighth of a dollar), well under 1% of every corpus
   price. *)
let _basis_gap_tol = 0.01

(* Split-day stop distance is an exact algebraic identity; allow float noise. *)
let _exact_tol = 1e-9

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _bar_on bars date =
  List.find_exn bars ~f:(fun (b : Types.Daily_price.t) -> Date.equal b.date date)

let _bar_before bars date =
  List.last_exn
    (List.take_while bars ~f:(fun (b : Types.Daily_price.t) ->
         Date.( < ) b.date date))

let _scale_bar k (b : Types.Daily_price.t) : Types.Daily_price.t =
  {
    b with
    open_price = b.open_price *. k;
    high_price = b.high_price *. k;
    low_price = b.low_price *. k;
    close_price = b.close_price *. k;
  }

(* ------------------------------------------------------------------ *)
(* Stage classifier                                                     *)
(* ------------------------------------------------------------------ *)

let _weekly (entry : Split_corpus.entry) =
  Array.of_list
    (Time_period.Conversion.daily_to_weekly ~include_partial_week:true
       entry.bars)

let _classify weekly i =
  Stage.classify ~config:_stage_config
    ~bars:(Array.to_list (Array.sub weekly ~pos:0 ~len:(i + 1)))
    ~prior_stage:None

let _close_over_ma weekly i =
  weekly.(i).Types.Daily_price.adjusted_close /. (_classify weekly i).ma_value

let _split_week weekly (s : Split_corpus.split) =
  fst
    (Option.value_exn
       (Array.findi weekly ~f:(fun _ (b : Types.Daily_price.t) ->
            Date.( >= ) b.date s.ex_date)))

(** Half the split's |log ratio| minus the |log| move of close/MA across the
    split week: positive when the classifier's basis is continuous. *)
let _stage_jump_headroom weekly (s : Split_corpus.split) =
  let i = _split_week weekly s in
  let jump =
    Float.abs (Float.log (_close_over_ma weekly i /. _close_over_ma weekly (i - 1)))
  in
  (Float.abs (Float.log s.ratio) /. 2.0) -. jump

(* ------------------------------------------------------------------ *)
(* Stops                                                                *)
(* ------------------------------------------------------------------ *)

let _initial_stop bars (entry_bar : Types.Daily_price.t) =
  Weinstein_stops.compute_initial_stop_with_floor ~config:_stops_config
    ~side:_long ~entry_price:entry_bar.close_price ~bars ~as_of:entry_bar.date
    ~fallback_buffer:_fallback_buffer

let _distance state (bar : Types.Daily_price.t) =
  (bar.close_price -. Weinstein_stops.get_stop_level state) /. bar.close_price

let _hit state bar = Weinstein_stops.check_stop_hit ~state ~side:_long ~bar ()

(** [(hit, distance)] on the ex-date bar read two ways: post-split basis (the
    stop rescaled by the split, the raw ex-date bar) and pre-split basis (the
    unscaled stop, the ex-date bar multiplied back by the ratio). *)
let _split_day_views bars (s : Split_corpus.split) =
  let prev = _bar_before bars s.ex_date in
  let ex = _bar_on bars s.ex_date in
  let pre_state = _initial_stop bars prev in
  let post_state =
    Weinstein_stops.Stop_split_adjust.scale ~factor:s.ratio pre_state
  in
  let ex_pre_basis = _scale_bar s.ratio ex in
  ( (_hit post_state ex, _distance post_state ex),
    (_hit pre_state ex_pre_basis, _distance pre_state ex_pre_basis) )

(** Product of the ratios of the entry's splits still ahead of [date]: dividing
    a raw price on [date] by it restates the price in the window's final
    basis. *)
let _pending_ratio (meta : Split_corpus.meta) date =
  List.fold meta.splits ~init:1.0 ~f:(fun acc (s : Split_corpus.split) ->
      if Date.( > ) s.ex_date date then acc *. s.ratio else acc)

let _restate meta (b : Types.Daily_price.t) =
  _scale_bar (1.0 /. _pending_ratio meta b.date) b

type paths = {
  raw : Weinstein_stops.stop_state;  (** Raw dollars, scaled at each ex-date. *)
  restated : Weinstein_stops.stop_state;  (** The window's final basis. *)
  last_date : Date.t;
}

let _advance (cls : Stage.result) ~bar ~ma state =
  fst
    (Weinstein_stops.update ~config:_stops_config ~side:_long ~state
       ~current_bar:bar ~ma_value:ma ~ma_direction:cls.ma_direction
       ~stage:cls.stage)

(** One weekly step of both paths, on the daily bar that closes week [i]. *)
let _step (meta : Split_corpus.meta) ~weekly ~bars acc i =
  let bar = _bar_on bars weekly.(i).Types.Daily_price.date in
  let cls = _classify weekly i in
  let ma_raw = cls.ma_value /. Split_corpus.adjustment_factor bar in
  let k = _pending_ratio meta bar.date in
  let crossed (s : Split_corpus.split) =
    Date.( > ) s.ex_date acc.last_date && Date.( <= ) s.ex_date bar.date
  in
  let raw_state =
    List.fold (List.filter meta.splits ~f:crossed) ~init:acc.raw
      ~f:(fun st (s : Split_corpus.split) ->
        Weinstein_stops.Stop_split_adjust.scale ~factor:s.ratio st)
  in
  {
    raw = _advance cls ~bar ~ma:ma_raw raw_state;
    restated =
      _advance cls ~bar:(_scale_bar (1.0 /. k) bar) ~ma:(ma_raw /. k)
        acc.restated;
    last_date = bar.date;
  }

(** [(relative gap between the two paths' stops, restated stop level)]. *)
let _gap_and_level meta p =
  let k = _pending_ratio meta p.last_date in
  let raw_level = Weinstein_stops.get_stop_level p.raw /. k in
  let level = Weinstein_stops.get_stop_level p.restated in
  (Float.abs (raw_level -. level) /. level, level)

(** Enter at the first week with a full MA, then walk both paths to the end of
    the window. One [(gap, level)] per week after entry. *)
let _trailing_run (entry : Split_corpus.entry) =
  let weekly = _weekly entry in
  let start = _stage_config.Stage.ma_period - 1 in
  let entry_bar = _bar_on entry.bars weekly.(start).Types.Daily_price.date in
  let restated_bars = List.map entry.bars ~f:(_restate entry.meta) in
  let init =
    {
      raw = _initial_stop entry.bars entry_bar;
      restated = _initial_stop restated_bars (_restate entry.meta entry_bar);
      last_date = entry_bar.date;
    }
  in
  List.folding_map
    (List.range (start + 1) (Array.length weekly))
    ~init
    ~f:(fun acc i ->
      let next = _step entry.meta ~weekly ~bars:entry.bars acc i in
      (next, _gap_and_level entry.meta next))

let _raises levels =
  List.zip_exn (List.drop_last_exn levels) (List.tl_exn levels)
  |> List.count ~f:(fun (before, after) -> Float.( > ) after before)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _test_close_over_ma_continuous name _ =
  let entry = _load name in
  let weekly = _weekly entry in
  assert_that
    (List.map entry.meta.splits ~f:(_stage_jump_headroom weekly))
    (all_of
       [
         field List.length (gt (module Int_ord) 0);
         each (gt (module Float_ord) 0.0);
       ])

let _test_split_day_stop_basis_invariant name _ =
  let entry = _load name in
  assert_that
    (List.map entry.meta.splits ~f:(_split_day_views entry.bars))
    (each
       (all_of
          [
            field
              (fun ((hit_post, _), (hit_pre, _)) -> Bool.equal hit_post hit_pre)
              (equal_to true);
            field
              (fun ((_, dist_post), (_, dist_pre)) -> dist_post -. dist_pre)
              (float_equal ~epsilon:_exact_tol 0.0);
          ]))

let _test_trailing_stop_basis_invariant name _ =
  assert_that
    (List.map (_trailing_run (_load name)) ~f:fst)
    (all_of
       [
         field List.length (gt (module Int_ord) 0);
         each (lt (module Float_ord) _basis_gap_tol);
       ])

(** Guards the trailing test above against vacuity: across the corpus the
    machine does ratchet (a frozen stop would be trivially basis-invariant). *)
let test_trailing_stop_ratchets_in_the_corpus _ =
  assert_that
    (List.sum
       (module Int)
       _entries
       ~f:(fun name -> _raises (List.map (_trailing_run (_load name)) ~f:snd)))
    (gt (module Int_ord) 0)

let _per_entry label test =
  List.map _entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

let suite =
  "split_corpus_stage_stops"
  >::: _per_entry "close_over_ma_continuous" _test_close_over_ma_continuous
       @ _per_entry "split_day_stop_basis_invariant"
           _test_split_day_stop_basis_invariant
       @ _per_entry "trailing_stop_basis_invariant"
           _test_trailing_stop_basis_invariant
       @ [
           "trailing_stop_ratchets_in_the_corpus"
           >:: test_trailing_stop_ratchets_in_the_corpus;
         ]

let () = run_test_tt_main suite
