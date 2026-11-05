(** Split corpus x prior-base level scan (issue #2973).

    The resistance / support scan the screener runs every Friday over the weekly
    bars: [Stock_analysis]'s breakout price (max high) and breakdown price (min
    low) over the prior-base window. The breakout price is the long ticket's
    anchor and the breakdown price the short's, so both must be read in the
    decision bar's basis — G14 truncates the scan at the most recent split so a
    pre-split high never prices a post-split ticket.

    Oracle: at a decision date, the level read on the loaded tape is the high
    (low) of some week of the prior-base window on the tape restated into the
    decision bar's basis ({!Split_corpus.restate_bar}, restated daily, then
    rolled to weekly). A level drawn from a week printed on another basis
    matches no restated week.

    Scope: the decision dates where G14's guard sees every split behind it — the
    split week sits at least [base_end_offset_weeks] back, and the ex-date opens
    its week. The other post-split dates break the oracle on the corpus and are
    recorded as findings, not asserted here (issue #2973, registry rows
    "prior-base scan blind ..." and "split-week weekly bar mixes bases ..."):
    for the [base_end_offset_weeks - 1] weeks after an ex-date the guard never
    compares the split boundary, and a mid-week ex-date folds pre-split highs
    into a weekly bar the guard reads as post-split. *)

open OUnit2
open Core
open Matchers

(** [(entry, guarded decision dates checked)]. Pinning the count keeps each
    per-entry case from passing vacuously. NVDA-2021-07-20 and ISRG-2017-10-06
    check none: their ex-dates are a Tuesday and a Friday (the split day is the
    screening day itself), so each split week mixes bases and every post-split
    date is out of scope (registry row "split-week weekly bar mixes bases"). The
    [0] is pinned so a guard change that brings those dates in is noticed. *)
let _entries =
  [
    ("AAPL-2014-06-09", 13);
    ("AAPL-2020-08-31", 13);
    ("C-1996-05-28", 26);
    ("GE-2021-08-02", 13);
    ("INFY-2014-12-08", 20);
    ("ISRG-2017-10-06", 0);
    ("NVDA-2021-07-20", 0);
    ("NVDA-2024-06-10", 13);
    ("TSLA-2020-08-31", 13);
  ]

let _sa_config = Stock_analysis.default_config

(* Levels are copied verbatim from one bar's high / low; allow float noise from
   the restatement multiply. *)
let _rel_tol = 1e-9

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _weekly bars =
  Array.of_list
    (Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars)

let _rel_eq a b = Float.( <= ) (Float.abs (a -. b)) (_rel_tol *. Float.abs b)

(** Index of the weekly bar holding [ex_date]. *)
let _split_week weekly (s : Split_corpus.split) =
  fst
    (Option.value_exn
       (Array.findi weekly ~f:(fun _ (b : Types.Daily_price.t) ->
            Date.( >= ) b.date s.ex_date)))

(** [true] when no daily bar of the split week precedes the ex-date, so the
    split week's weekly bar is wholly post-split. *)
let _opens_its_week (entry : Split_corpus.entry) weekly s =
  let i = _split_week weekly s in
  i = 0
  || List.for_all entry.bars ~f:(fun (b : Types.Daily_price.t) ->
      Date.( >= ) b.date s.ex_date || Date.( <= ) b.date weekly.(i - 1).date)

type decision = {
  date : Date.t;
  loaded : Types.Daily_price.t list;
  restated : Types.Daily_price.t list;
}
(** One weekly decision date: the loaded weekly tape and the tape restated into
    the decision bar's basis, both truncated at the decision week. *)

(** [true] when G14's guard sees every split on or before decision week [i]. *)
let _guarded (entry : Split_corpus.entry) weekly i =
  List.for_all entry.meta.splits ~f:(fun s ->
      let w = _split_week weekly s in
      w > i
      || i - w >= _sa_config.base_end_offset_weeks
         && _opens_its_week entry weekly s)

(** Every guarded weekly decision date on or after the first ex-date. *)
let _decisions (entry : Split_corpus.entry) =
  let first_ex = (List.hd_exn entry.meta.splits).ex_date in
  let loaded = _weekly entry.bars in
  Array.to_list loaded
  |> List.filter_mapi ~f:(fun i (week : Types.Daily_price.t) ->
      if Date.( < ) week.date first_ex || not (_guarded entry loaded i) then
        None
      else
        let restated =
          _weekly
            (List.map entry.bars
               ~f:(Split_corpus.restate_bar entry.meta ~as_of:week.date))
        in
        Some
          {
            date = week.date;
            loaded = Array.to_list (Array.sub loaded ~pos:0 ~len:(i + 1));
            restated = Array.to_list (Array.sub restated ~pos:0 ~len:(i + 1));
          })

(** The restated weeks the prior-base scan may read: offsets
    [base_end_offset_weeks .. base_lookback_weeks - 1] back from the decision
    week. *)
let _base_window (d : decision) =
  let n = List.length d.restated in
  let first = Int.max 0 (n - _sa_config.base_lookback_weeks) in
  let last = n - 1 - _sa_config.base_end_offset_weeks in
  if last < first then []
  else List.sub d.restated ~pos:first ~len:(last - first + 1)

(** [true] when the level is unset or is the price of a restated window week. *)
let _on_basis ~price (d : decision) level =
  Option.for_all level ~f:(fun l ->
      List.exists (_base_window d) ~f:(fun w -> _rel_eq l (price w)))

(** [(date, breakout on basis, breakdown on basis)] per guarded decision. *)
let _scan_reads (entry : Split_corpus.entry) =
  List.map (_decisions entry) ~f:(fun d ->
      let a =
        Stock_analysis.analyze ~config:_sa_config ~ticker:entry.meta.symbol
          ~bars:d.loaded ~benchmark_bars:[] ~prior_stage:None ~as_of_date:d.date
      in
      ( d.date,
        _on_basis
          ~price:(fun w -> w.Types.Daily_price.high_price)
          d a.breakout_price,
        _on_basis
          ~price:(fun w -> w.Types.Daily_price.low_price)
          d a.breakdown_price ))

let _off_basis_dates reads =
  List.filter_map reads ~f:(fun (date, up, down) ->
      if up && down then None else Some date)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _test_scan_level_on_decision_basis (name, n_decisions) _ =
  assert_that
    (_scan_reads (_load name))
    (all_of
       [
         field List.length (equal_to n_decisions);
         field _off_basis_dates (equal_to ([] : Date.t list));
       ])

(** Guards the test above against vacuity: the corpus holds guarded post-split
    decision dates for both split directions (a forward split and GE's 1:8
    reverse). *)
let test_scan_covers_forward_and_reverse_splits _ =
  let count name = List.length (_scan_reads (_load name)) in
  assert_that
    (count "AAPL-2014-06-09", count "GE-2021-08-02")
    (all_of
       [ field fst (gt (module Int_ord) 0); field snd (gt (module Int_ord) 0) ])

let _per_entry label test =
  List.map _entries ~f:(fun ((name, _) as entry) ->
      Printf.sprintf "%s/%s" label name >:: test entry)

let suite =
  "split_corpus_scan"
  >::: _per_entry "scan_level_on_decision_basis"
         _test_scan_level_on_decision_basis
       @ [
           "scan_covers_forward_and_reverse_splits"
           >:: test_scan_covers_forward_and_reverse_splits;
         ]

let () = run_test_tt_main suite
