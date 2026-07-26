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
  }

let _size ?(placeholder = false) ?(entry = 100.0) ?(stop = 90.0) () =
  Trade_sizing.size_candidate ~risk_config:Portfolio_risk.default_config
    ~portfolio_value:100_000.0 ~sizing_cash:100_000.0 ~side:`Long ~placeholder
    { _candidate with entry; stop }

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

let suite =
  "trade_sizing"
  >::: [
         "fixed_risk_sizing_pinned" >:: test_fixed_risk_sizing_pinned;
         "tighter_stop_more_shares" >:: test_tighter_stop_more_shares;
         "placeholder_note" >:: test_placeholder_note;
         "invalid_stop_direction" >:: test_invalid_stop_direction;
       ]

let () = run_test_tt_main suite
