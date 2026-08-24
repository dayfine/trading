(** Tests for {!Trade_sizing} — fixed-risk sizing of a weekly-pick candidate,
    mirroring the backtest's {!Portfolio_risk.compute_position_size}. *)

open OUnit2
open Matchers
open Weinstein_snapshot
module Trade_sizing = Weinstein_snapshot_gen.Trade_sizing

(* Candidate entered at $100 with a $90 stop: $10 risk/share. *)
let _candidate : Weekly_snapshot.candidate =
  {
    symbol = "TEST";
    score = 100.0;
    grade = "A+";
    entry = 100.0;
    stop = 90.0;
    sector = "XLK";
    rationale = "test";
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

let _size ?(placeholder = false) ?(entry = 100.0) ?(stop = 90.0)
    ?(reconciliation = Entry_reconciliation.Not_reconciled) () =
  Trade_sizing.size_candidate ~risk_config:Portfolio_risk.default_config
    ~portfolio_value:100_000.0 ~sizing_cash:100_000.0 ~side:`Long ~placeholder
    { _candidate with entry; stop; reconciliation }

let _shares (c : Weekly_snapshot.candidate) = c.sized_shares
let _value (c : Weekly_snapshot.candidate) = c.sized_position_value
let _pct (c : Weekly_snapshot.candidate) = c.sized_position_pct
let _risk (c : Weekly_snapshot.candidate) = c.sized_risk_amount
let _note (c : Weekly_snapshot.candidate) = c.sizing_note

(* Hand computation on the default config (risk 1%, per-pos cap 30%, exposure
   90%, cash 100%): risk-based shares = floor((100000*0.01)/10) = 100; every
   cap is looser, so 100 binds. value = 100*100 = 10000 (10% of book); risk =
   100*10 = 1000. Note is [None] on a normal fill. *)
let test_fixed_risk_sizing_pinned _ =
  assert_that (_size ())
    (all_of
       [
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
           (equal_to 100);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_position_value)
           (float_equal 10_000.0);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_position_pct)
           (float_equal 0.10);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_risk_amount)
           (float_equal 1000.0);
         field (fun (c : Weekly_snapshot.candidate) -> c.sizing_note) is_none;
       ])

(* A tighter stop earns MORE shares for the same dollar risk — the documented
   "not equal-sized" property. $5 risk/share (stop $95) doubles the share
   count vs the $10-risk baseline. *)
let test_tighter_stop_more_shares _ =
  assert_that (_size ~stop:95.0 ())
    (field
       (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
       (equal_to 200))

(* Placeholder sizing stamps the UNSIZED note while still filling the numbers. *)
let test_placeholder_note _ =
  assert_that
    (_size ~placeholder:true ())
    (all_of
       [
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
           (equal_to 100);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sizing_note)
           (is_some_and (equal_to "UNSIZED — set portfolio.sexp"));
       ])

(* An invalid stop direction (stop above entry for a long) sizes to zero and
   surfaces the direction reason. *)
let test_invalid_stop_direction _ =
  assert_that
    (_size ~entry:100.0 ~stop:110.0 ())
    (all_of
       [
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
           (equal_to 0);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.sizing_note)
           (is_some_and
              (equal_to
                 "0 sh — invalid stop direction (stop on wrong side of entry)"));
       ])

(* ------------------------------------------------------------------ *)
(* Entry reconciliation (issues #2103, #2158): sizing on the CAP        *)
(* ------------------------------------------------------------------ *)

(* Reconciliation classes built through the REAL classifier with the armed
   thresholds (band 1pt, chase cap 15pt) so the do-not-chase [cap] field is
   the one production computes — entry $100 -> cap $115. The candidate's own
   entry is $100, matching. *)
let _classify ~close =
  Entry_reconciliation.classify ~side:`Long ~entry:100.0 ~close
    ~through_band_pct:1.0 ~extension_max_pct:15.0

(* {b The pin for issue #2158 ("size on the cap").} A through-entry candidate is
   sized on the WORST admissible fill — the do-not-chase cap ($115.00) the live
   [StopLimit] order caps at — not on the expected fill ($107.30) and not on the
   stale $100.00 breakout level.

   Hand computation, default config (risk 1%, per-pos cap 30%, exposure 90%,
   cash 100%), portfolio $100,000, stop $90.00, cap $115.00:

     risk/share  = |115.00 - 90.00|         = 25.00
     risk shares = floor(1000 / 25.00)      = 40
     per-pos cap = floor(30000 / 115.00)    = 260     (looser)
     shares      = min(...)                 = 40
     value       = 40 * 115.00              = 4600.00
     pct         = 4600.00 / 100000         = 0.046
     risk        = 40 * 25.00               = 1000.00

   Sizing on the expected fill ($107.30) — the pre-#2158 behaviour — would give
   57 shares, $6,116.10 of value and $986.10 of risk; sizing on the stale entry
   ($100.00) would give 100 / $10,000 / $1,000. All four numbers below differ
   from both, so this test pins the cap basis specifically. *)
let test_through_entry_sized_on_the_cap _ =
  assert_that
    (_size ~reconciliation:(_classify ~close:107.3) ())
    (all_of
       [
         field _shares (equal_to 40);
         field _value (float_equal 4600.0);
         field _pct (float_equal 0.046);
         field _risk (float_equal 1000.0);
         field _note is_none;
       ])

(* Size-on-cap is invariant to WHERE inside the band the close sits: two
   through-entry candidates with different closes ($107.30 and $112.00) but the
   same $115.00 cap size identically, because the worst admissible fill is the
   cap in both cases. (Under the old expected-fill basis these would have sized
   differently — 57 vs 45 shares.) *)
let test_size_is_on_the_cap_not_the_close _ =
  let at_107 = _size ~reconciliation:(_classify ~close:107.3) () in
  let at_112 = _size ~reconciliation:(_classify ~close:112.0) () in
  assert_that (_shares at_112) (equal_to (_shares at_107))

(* A valid-stop candidate is ALSO sized on the cap: its resting [StopLimit (E,
   cap)] can fill anywhere up to the cap, so the honest-conservative size is the
   worst case ($115.00), identical to the through-entry cap sizing above — NOT
   the $100 entry. This differs from the [Not_reconciled] baseline (100 sh),
   which stays sized on the entry because it carries no cap (the R1 no-op). *)
let test_valid_stop_sized_on_the_cap _ =
  assert_that
    (_size ~reconciliation:(_classify ~close:96.0) ())
    (all_of
       [
         field _shares (equal_to 40);
         field _value (float_equal 4600.0);
         field _risk (float_equal 1000.0);
       ])

(* Issue #2404: an EXTENDED candidate is sized like every other class — on the
   same $115.00 cap. Its order is the same capped [StopLimit]; it merely will
   not fill at today's price and would fill at the cap if price returned into
   the band, so the cap is its honest basis too. Identical numbers to the
   valid-stop and through-entry cases above; before #2404 all four read zero. *)
let test_extended_is_sized_on_the_cap _ =
  assert_that
    (_size ~reconciliation:(_classify ~close:134.5) ())
    (all_of
       [
         field _shares (equal_to 40);
         field _value (float_equal 4600.0);
         field _pct (float_equal 0.046);
         field _risk (float_equal 1000.0);
         field _note is_none;
       ])

let suite =
  "trade_sizing"
  >::: [
         "fixed_risk_sizing_pinned" >:: test_fixed_risk_sizing_pinned;
         "tighter_stop_more_shares" >:: test_tighter_stop_more_shares;
         "placeholder_note" >:: test_placeholder_note;
         "invalid_stop_direction" >:: test_invalid_stop_direction;
         "through-entry is sized on the cap, not the close"
         >:: test_through_entry_sized_on_the_cap;
         "size is on the cap, not the close"
         >:: test_size_is_on_the_cap_not_the_close;
         "valid-stop is sized on the cap" >:: test_valid_stop_sized_on_the_cap;
         "extended is sized on the cap" >:: test_extended_is_sized_on_the_cap;
       ]

let () = run_test_tt_main suite
