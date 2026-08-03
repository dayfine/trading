(** Tests for {!Entry_reconcile} — the bar-reader-backed pass that stamps each
    candidate's reconciliation class at the generate seam (issue #2103).

    {!Entry_reconciliation} owns (and is separately tested for) the
    classification itself; what is pinned here is the {e pass}: that it reads
    the right close off the bar reader, that it degrades honestly when it
    cannot, that the [side] it is handed reaches the classifier, and that it
    annotates rather than drops.

    Bars are built directly as [(symbol, Daily_price.t list)] pairs fed to
    {!Bar_reader.of_in_memory_bars}, so every close is exact. Each symbol gets a
    DIFFERENT last close, chosen to land in a different class — a pass that
    stamped one class on everything, or read the wrong bar, cannot satisfy all
    three. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Reconcile = Weinstein_snapshot_gen.Entry_reconcile

let _band = 1.0
let _cap = 15.0
let _entry = 100.0
let _as_of = Date.of_string "2026-07-24"

let _bar ~close date : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Three ascending weekday bars ending at [_as_of], of which only the LAST one's
   close should be picked up. The two earlier closes are deliberately in a
   different class from the last (99.0 would be valid-stop) so a pass that read
   the first bar, or the wrong end of the list, lands in the wrong class. *)
let _bars ~last_close =
  [
    _bar ~close:99.0 (Date.of_string "2026-07-22");
    _bar ~close:99.5 (Date.of_string "2026-07-23");
    _bar ~close:last_close _as_of;
  ]

let _candidate ~symbol : Weekly_snapshot.candidate =
  {
    symbol;
    score = 85.0;
    grade = "A+";
    entry = _entry;
    stop = 92.0;
    sector = "Health Care";
    rationale = "Early Stage2";
    rs_vs_spy = None;
    resistance_grade = None;
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
    stop_is_structural = false;
    data_suspect = false;
    reconciliation = Entry_reconciliation.Not_reconciled;
    score_components = [];
  }

(* One reader carrying three symbols whose last closes land in three DIFFERENT
   classes for a long: VALID below entry, THRU +7.3%, EXT +34.5% (the MBX
   shape). *)
let _reader () =
  Bar_reader.of_in_memory_bars
    [
      ("VALID", _bars ~last_close:96.0);
      ("THRU", _bars ~last_close:107.3);
      ("EXT", _bars ~last_close:134.5);
    ]

let _reconcile ?(reader = _reader ()) ?(side = `Long)
    ?(through_band_pct = _band) ?(extension_max_pct = _cap) symbol =
  Reconcile.for_candidate reader ~as_of:_as_of ~side ~through_band_pct
    ~extension_max_pct (_candidate ~symbol)

let _class_of (c : Weekly_snapshot.candidate) =
  Entry_reconciliation.label c.reconciliation

let _is_class name = field _class_of (is_some_and (equal_to name))

(* ---- The pass reads the LAST close and classifies off it ---- *)

let test_valid_stop_symbol _ =
  assert_that (_reconcile "VALID") (_is_class "valid-stop")

let test_through_entry_symbol _ =
  assert_that (_reconcile "THRU") (_is_class "through-entry")

let test_extended_symbol _ =
  assert_that (_reconcile "EXT") (_is_class "EXTENDED")

(* The close carried into the record is the LAST bar's, not the first's — this
   is the value sizing will anchor to, so reading the wrong bar is the #2103 bug
   in a different costume. *)
let test_close_is_the_last_bar _ =
  assert_that (_reconcile "THRU")
    (field
       (fun (c : Weekly_snapshot.candidate) ->
         Entry_reconciliation.levels_of c.reconciliation)
       (is_some_and
          (field
             (fun (l : Entry_reconciliation.levels) -> l.close)
             (float_equal 107.3))))

(* [expected_fill_price] follows: a through-entry candidate will be sized on the
   close, everything else on the entry level. *)
let test_expected_fill_price_follows_class _ =
  assert_that
    (Weekly_snapshot.expected_fill_price (_reconcile "THRU"))
    (float_equal 107.3)

let test_expected_fill_price_is_entry_for_valid_stop _ =
  assert_that
    (Weekly_snapshot.expected_fill_price (_reconcile "VALID"))
    (float_equal _entry)

(* An extended candidate is NOT re-anchored: there is no order, so there is no
   fill to price. *)
let test_expected_fill_price_is_entry_for_extended _ =
  assert_that
    (Weekly_snapshot.expected_fill_price (_reconcile "EXT"))
    (float_equal _entry)

(* ---- [side] reaches the classifier ---- *)

(* The SAME symbol and the SAME bars classify oppositely by side: a close 4%
   below a long's breakout has not reached it (valid-stop), while a close 4%
   below a short's breakdown level is already through it (through-entry). A pass
   that dropped [side] on the floor would return one class for both. *)
let test_side_flips_the_class_on_identical_bars _ =
  assert_that (_reconcile ~side:`Short "VALID") (_is_class "through-entry")

let test_short_above_entry_is_valid_stop _ =
  assert_that (_reconcile ~side:`Short "THRU") (_is_class "valid-stop")

(* ---- Honest degradation ---- *)

(* Disarmed (the [0.0] default): the candidate comes back untouched, so the
   generator behaves exactly as it did before #2103. Asserted on the whole
   record, not just the class, to pin "unchanged" rather than "unclassified". *)
let test_disarmed_returns_candidate_unchanged _ =
  assert_that
    (_reconcile ~extension_max_pct:0.0 "EXT")
    (equal_to (_candidate ~symbol:"EXT"))

(* A symbol with no resident bars cannot be priced: report [Not_reconciled]
   rather than assuming the entry is still valid. *)
let test_no_bars_is_not_reconciled _ =
  assert_that
    (_reconcile ~reader:(Bar_reader.empty ()) "EXT")
    (equal_to (_candidate ~symbol:"EXT"))

(* ---- [for_candidates] annotates, never drops or reorders ---- *)

(* An over-extended name KEEPS its row (the issue is explicit: suppress the
   ticket, keep the row for watch purposes), and rank order is preserved. *)
let test_for_candidates_preserves_order_and_membership _ =
  let candidates =
    List.map [ "EXT"; "VALID"; "THRU" ] ~f:(fun symbol -> _candidate ~symbol)
  in
  let out =
    Reconcile.for_candidates (_reader ()) ~as_of:_as_of ~side:`Long
      ~through_band_pct:_band ~extension_max_pct:_cap candidates
  in
  assert_that out
    (elements_are
       [
         all_of
           [
             field
               (fun (c : Weekly_snapshot.candidate) -> c.symbol)
               (equal_to "EXT");
             _is_class "EXTENDED";
           ];
         all_of
           [
             field
               (fun (c : Weekly_snapshot.candidate) -> c.symbol)
               (equal_to "VALID");
             _is_class "valid-stop";
           ];
         all_of
           [
             field
               (fun (c : Weekly_snapshot.candidate) -> c.symbol)
               (equal_to "THRU");
             _is_class "through-entry";
           ];
       ])

let suite =
  "entry_reconcile"
  >::: [
         "valid-stop symbol" >:: test_valid_stop_symbol;
         "through-entry symbol" >:: test_through_entry_symbol;
         "extended symbol" >:: test_extended_symbol;
         "close is the last bar's" >:: test_close_is_the_last_bar;
         "expected fill price follows the class"
         >:: test_expected_fill_price_follows_class;
         "expected fill price is entry for valid-stop"
         >:: test_expected_fill_price_is_entry_for_valid_stop;
         "expected fill price is entry for extended"
         >:: test_expected_fill_price_is_entry_for_extended;
         "side flips the class on identical bars"
         >:: test_side_flips_the_class_on_identical_bars;
         "short above entry is valid-stop"
         >:: test_short_above_entry_is_valid_stop;
         "disarmed returns the candidate unchanged"
         >:: test_disarmed_returns_candidate_unchanged;
         "no bars is not-reconciled" >:: test_no_bars_is_not_reconciled;
         "for_candidates preserves order and membership"
         >:: test_for_candidates_preserves_order_and_membership;
       ]

let () = run_test_tt_main suite
