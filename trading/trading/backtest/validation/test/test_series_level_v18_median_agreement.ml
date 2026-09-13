(** Drift detector for the one statistic V18 and its build-time sibling compute
    twice.

    {!Post_run_validator.Validator_store_check}'s [_v18_median_close] and
    {!Snapshot_pipeline.Series_level}'s [_median_close] are two independent
    copies of the same function — same sort, same even-length mean of the two
    central closes — living in different libraries, neither able to call the
    other. {!Snapshot_pipeline.Series_level}'s header claims they agree; nothing
    checked it, and two copies of a statistic drift silently. This file feeds
    one bar set to both halves and compares the medians they report.

    {b Scope of the claim being pinned.} Only the median {e function} is shared.
    The two halves feed it different inputs — [Series_level] drops non-finite
    closes before any statistic is taken and counts only the survivors against
    its [min_bars], while V18 sorts the stored array raw and counts all of it —
    so on a NaN-carrying series the two medians differ {e by construction}
    ([Float.compare] orders [nan] below every real price). That divergence is
    documented, not a defect, and is deliberately not asserted here: these cases
    are all finite, which is every series the warehouse scans produced. *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Series_level = Snapshot_pipeline.Series_level

let _start = Date.of_string "2017-01-02"

(* One (date, close) spine rendered into each half's own bar type, so the two
   implementations provably see the same numbers in the same order. Volume is
   positive throughout: V18's phantom-print rule short-circuits on a traded bar,
   so only its LEVEL half — the half Series_level mirrors — can fire. *)
let _dates closes = List.mapi closes ~f:(fun i _ -> Date.add_days _start i)

let _v18_bars closes : Vt.daily_bar list =
  List.map2_exn (_dates closes) closes ~f:(fun date close ->
      {
        Vt.date;
        open_price = close;
        high = close;
        low = close;
        close;
        adjusted_close = close;
        volume = 1_000_000;
      })

let _level_bars closes =
  List.map2_exn (_dates closes) closes ~f:(fun date close ->
      Types.Daily_price.make ~date ~open_price:close ~high_price:close
        ~low_price:close ~close_price:close ~volume:1_000_000
        ~adjusted_close:close ())

let _trade ~symbol () : Vt.trade_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string "2017-01-30";
    exit_date = Date.of_string "2017-02-08";
    entry_price = 100.0;
    exit_price = 110.0;
    quantity = 1.0;
    exit_trigger = "stop_loss";
    stop_trigger_kind = "gap_down";
    stop_initial_distance_pct = None;
    position_id = None;
    stop_fill_distance_pct = None;
  }

(* V18 surfaces its median only as prose inside a violation specimen —
   "median close 55000.00 over 20 bars (...)" — so reading it back is the only
   way to compare the two implementations without exporting a private helper. *)
let _parse_median detail =
  let head = "median close " in
  match String.substr_index detail ~pattern:head with
  | None -> assert_failure ("no median in V18 detail: " ^ detail)
  | Some i -> (
      let rest = String.drop_prefix detail (i + String.length head) in
      match String.substr_index rest ~pattern:" over " with
      | None -> assert_failure ("no span in V18 detail: " ^ detail)
      | Some j -> Float.of_string (String.prefix rest j))

let _store ~symbol closes s : Vt.bars option =
  if String.equal s symbol then
    Some
      {
        weekly_dates = [||];
        weekly_closes = [||];
        daily = Array.of_list (_v18_bars closes);
      }
  else None

(* Every case sits above the $10,000 ceiling so that V18 produces a specimen at
   all — which is also what makes Series_level return a finding to read
   [median_close] off. *)
let _v18_median ~symbol closes =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol () ];
      bars = _store ~symbol closes;
    }
  in
  match (Vc.run_check ~id:"V18" inputs).specimens with
  | [ sp ] -> _parse_median sp.detail
  | _ -> assert_failure (symbol ^ ": expected exactly one V18 specimen")

let _level_median ~symbol closes =
  let config = { Series_level.Config.default with enabled = true } in
  match Series_level.classify config ~symbol (_level_bars closes) with
  | Some (f : Series_level.finding) -> f.median_close
  | None -> assert_failure (symbol ^ ": expected a Series_level finding")

(* The assertion: one bar set, both halves, same median. V18 renders at two
   decimals, so every case is chosen to differ by far more than that if the two
   implementations ever disagree. *)
let _assert_agree ~symbol closes =
  assert_that
    (_level_median ~symbol closes)
    (float_equal ~epsilon:0.005 (_v18_median ~symbol closes))

(** Odd length: the median is a single stored close and both halves must pick
    the same element of the sorted array. *)
let test_odd_length_medians_agree _ =
  _assert_agree ~symbol:"ODD"
    (List.init 21 ~f:(fun i -> 50_000.0 +. (100.0 *. Float.of_int i)))

(** {b The case that matters.} Even length with the two central closes
    {e differing}: the median is their mean (55,000) and is a number no bar in
    the series carries. Dropping the even-length branch in either copy — taking
    [sorted.(n / 2)] alone, the obvious simplification — yields 60,000 on one
    side and 55,000 on the other, and only this shape catches it. *)
let test_even_length_medians_agree_when_the_central_closes_differ _ =
  _assert_agree ~symbol:"EVEN"
    (List.init 10 ~f:(fun _ -> 50_000.0) @ List.init 10 ~f:(fun _ -> 60_000.0))

(** A second even-length shape, at the real defect's proportions: MEL's $172k
    plateau with correctly-scaled prints mixed in, so the sort order — not just
    the arithmetic — has to match. *)
let test_even_length_medians_agree_on_a_two_scale_series _ =
  _assert_agree ~symbol:"MEL"
    (List.init 30 ~f:(fun _ -> 172_140.0)
    @ List.init 10 ~f:(fun _ -> 12.20)
    @ List.init 2 ~f:(fun _ -> 90_000.0))

let suite =
  "series_level_v18_median_agreement"
  >::: [
         "odd length medians agree" >:: test_odd_length_medians_agree;
         "even length medians agree when the central closes differ"
         >:: test_even_length_medians_agree_when_the_central_closes_differ;
         "even length medians agree on a two scale series"
         >:: test_even_length_medians_agree_on_a_two_scale_series;
       ]

let () = run_test_tt_main suite
