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
(* Entry reconciliation (issue #2103): sizing on the expected FILL      *)
(* ------------------------------------------------------------------ *)

let _through_entry ~close =
  Entry_reconciliation.Through_entry
    { close; overshoot_pct = (close -. 100.0) /. 100.0 *. 100.0 }

let _extended ~close =
  Entry_reconciliation.Extended
    { close; overshoot_pct = (close -. 100.0) /. 100.0 *. 100.0 }

(* {b The pin for issue #2103.} A candidate whose $100.00 breakout entry the
   price has already run 7.3% past is sized on the FILL ($107.30), never on the
   stale level.

   Hand computation, default config (risk 1%, per-pos cap 30%, exposure 90%,
   cash 100%), portfolio $100,000, stop $90.00:

     risk/share  = |107.30 - 90.00|         = 17.30
     risk shares = floor(1000 / 17.30)      = floor(57.803...) = 57
     per-pos cap = floor(30000 / 107.30)    = 279     (looser)
     exposure    = floor(90000 / 107.30)    = 838     (looser)
     cash        = floor(100000 / 107.30)   = 932     (looser)
     shares      = min(...)                 = 57
     value       = 57 * 107.30              = 6116.10
     pct         = 6116.10 / 100000         = 0.061161
     risk        = 57 * 17.30               = 986.10

   Sizing on the STALE entry — the pre-fix behaviour — would give 100 shares,
   $10,000 of value and $1,000 of stated risk, while the position would really
   cost 100 * 107.30 = $10,730 and risk 100 * 17.30 = $1,730. Every one of the
   four numbers below therefore differs between the two implementations, so
   this test cannot pass against the bug. (On the real MBX row the same
   arithmetic ran 651 sh @ $46.08 with the stock at $62: $784 of displayed risk
   against ~$11,145 of real risk, 14x.) *)
let test_through_entry_sized_on_the_fill_not_the_entry _ =
  assert_that
    (_size ~reconciliation:(_through_entry ~close:107.3) ())
    (all_of
       [
         field _shares (equal_to 57);
         field _value (float_equal 6116.10);
         field _pct (float_equal 0.061161);
         field _risk (float_equal 986.10);
         field _note is_none;
       ])

(* The re-sizing is not a fixed haircut: a bigger overshoot inside the cap costs
   more per share and earns fewer of them.

     risk/share  = |112.00 - 90.00|      = 22.00
     risk shares = floor(1000 / 22.00)   = 45
     value       = 45 * 112.00           = 5040.00
     risk        = 45 * 22.00            = 990.00 *)
let test_larger_overshoot_sizes_smaller _ =
  assert_that
    (_size ~reconciliation:(_through_entry ~close:112.0) ())
    (all_of
       [
         field _shares (equal_to 45);
         field _value (float_equal 5040.0);
         field _risk (float_equal 990.0);
       ])

(* A valid-stop candidate is sized on the entry level exactly as before — the
   resting order really does fill there. Identical to the [Not_reconciled]
   baseline above (100 / 10000 / 1000), which is the R1 no-op guarantee. *)
let test_valid_stop_sized_on_the_entry _ =
  assert_that
    (_size
       ~reconciliation:
         (Entry_reconciliation.Valid_stop { close = 96.0; overshoot_pct = -4.0 })
       ())
    (all_of
       [
         field _shares (equal_to 100);
         field _value (float_equal 10_000.0);
         field _risk (float_equal 1000.0);
       ])

(* An EXTENDED candidate has its ticket suppressed, so it carries no size at
   all — not a size computed at the stale entry, and not one computed at a fill
   the reader is being told NOT to take. All four numeric fields are zero and
   the note is empty (the do-not-chase reason is the instruction's job, not the
   sizing note's). *)
let test_extended_is_left_unsized _ =
  assert_that
    (_size ~reconciliation:(_extended ~close:134.5) ())
    (all_of
       [
         field _shares (equal_to 0);
         field _value (float_equal 0.0);
         field _pct (float_equal 0.0);
         field _risk (float_equal 0.0);
         field _note is_none;
       ])

(* Re-sizing an ALREADY-SIZED candidate into the extended class clears the stale
   numbers rather than leaving them beside a suppressed order. *)
let test_extended_clears_a_previous_size _ =
  let sized = _size () in
  assert_that
    (Trade_sizing.size_candidate ~risk_config:Portfolio_risk.default_config
       ~portfolio_value:100_000.0 ~sizing_cash:100_000.0 ~side:`Long
       ~placeholder:false
       { sized with reconciliation = _extended ~close:134.5 })
    (all_of [ field _shares (equal_to 0); field _value (float_equal 0.0) ])

let suite =
  "trade_sizing"
  >::: [
         "fixed_risk_sizing_pinned" >:: test_fixed_risk_sizing_pinned;
         "tighter_stop_more_shares" >:: test_tighter_stop_more_shares;
         "placeholder_note" >:: test_placeholder_note;
         "invalid_stop_direction" >:: test_invalid_stop_direction;
         "through-entry is sized on the fill, not the entry"
         >:: test_through_entry_sized_on_the_fill_not_the_entry;
         "a larger overshoot sizes smaller"
         >:: test_larger_overshoot_sizes_smaller;
         "valid-stop is sized on the entry"
         >:: test_valid_stop_sized_on_the_entry;
         "extended is left unsized" >:: test_extended_is_left_unsized;
         "extended clears a previous size"
         >:: test_extended_clears_a_previous_size;
       ]

let () = run_test_tt_main suite
