(** Tests for {!Portfolio_edit} — the pure book-keeping behind [record_fill].

    The through-line of every test here is that cash and the position list move
    together: each happy-path case pins the resulting cash numerically, and each
    error case asserts the portfolio was rejected outright rather than
    half-applied. *)

open Core
open OUnit2
open Matchers
module Live_portfolio = Weinstein_snapshot_gen.Live_portfolio
module Portfolio_edit = Weinstein_snapshot_gen.Portfolio_edit

let _date d = Date.of_string d
let _as_of = _date "2026-07-31"

let _aapl : Live_portfolio.position =
  {
    symbol = "AAPL";
    shares = 100;
    entry_price = 180.0;
    entry_date = _date "2026-06-13";
    stop_price = 168.0;
  }

(* 100k cash, one 100-share AAPL position. *)
let _held : Live_portfolio.t =
  { cash = 100_000.0; as_of = _date "2026-07-24"; positions = [ _aapl ] }

let _empty : Live_portfolio.t =
  { cash = 100_000.0; as_of = _date "2026-07-24"; positions = [] }

let _msg result = Result.error result |> Option.map ~f:Error.to_string_hum
let _cash (t : Live_portfolio.t) = t.cash
let _positions (t : Live_portfolio.t) = t.positions
let _symbol (p : Live_portfolio.position) = p.symbol
let _shares (p : Live_portfolio.position) = p.shares
let _stop (p : Live_portfolio.position) = p.stop_price

(* --- record ------------------------------------------------------------- *)

(* The happy path appends the position and debits 100 * 180.0 = 18_000.0. *)
let test_record_appends_and_debits _ =
  assert_that
    (Result.ok (Portfolio_edit.record _empty ~as_of:_as_of ~position:_aapl))
    (is_some_and
       (all_of
          [
            field _cash (float_equal 82_000.0);
            field (fun t -> t.Live_portfolio.as_of) (equal_to _as_of);
            field _positions (elements_are [ equal_to _aapl ]);
          ]))

(* A lower-case ticker is stored upper-case. *)
let test_record_normalizes_symbol _ =
  let position = { _aapl with symbol = "aapl" } in
  assert_that
    (Result.ok (Portfolio_edit.record _empty ~as_of:_as_of ~position))
    (is_some_and
       (field _positions (elements_are [ field _symbol (equal_to "AAPL") ])))

(* Idempotency: recording the same fill twice fails rather than doubling the
   position or double-debiting cash. *)
let test_record_rejects_duplicate _ =
  let once = Portfolio_edit.record _empty ~as_of:_as_of ~position:_aapl in
  let twice =
    Result.bind once ~f:(fun t ->
        Portfolio_edit.record t ~as_of:_as_of ~position:_aapl)
  in
  assert_that (_msg twice) (is_some_and (contains_substring "already held"))

(* Case-insensitivity applies to the duplicate check too. *)
let test_record_rejects_duplicate_other_case _ =
  let result =
    Portfolio_edit.record _held ~as_of:_as_of
      ~position:{ _aapl with symbol = "aapl" }
  in
  assert_that (_msg result) (is_some_and (contains_substring "already held"))

(* A fill costing more than the cash on hand is rejected, not overdrawn. *)
let test_record_rejects_insufficient_cash _ =
  let result =
    Portfolio_edit.record
      { _empty with cash = 1_000.0 }
      ~as_of:_as_of ~position:_aapl
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "insufficient cash"))

(* Weinstein's initial stop sits below the entry (book-reference §5.1). *)
let test_record_rejects_stop_above_entry _ =
  let result =
    Portfolio_edit.record _empty ~as_of:_as_of
      ~position:{ _aapl with stop_price = 190.0 }
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "must sit below entry-price"))

let test_record_rejects_non_positive_shares _ =
  let result =
    Portfolio_edit.record _empty ~as_of:_as_of
      ~position:{ _aapl with shares = 0 }
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "shares must be positive"))

(* --- close -------------------------------------------------------------- *)

(* A full exit credits 100 * 200.0 = 20_000.0 and drops the holding. *)
let test_close_credits_and_removes _ =
  assert_that
    (Result.ok
       (Portfolio_edit.close _held ~as_of:_as_of ~symbol:"AAPL"
          ~exit_price:200.0))
    (is_some_and
       (all_of
          [
            field _cash (float_equal 120_000.0);
            field (fun t -> t.Live_portfolio.as_of) (equal_to _as_of);
            field _positions is_empty;
          ]))

let test_close_normalizes_symbol _ =
  assert_that
    (Result.ok
       (Portfolio_edit.close _held ~as_of:_as_of ~symbol:"aapl"
          ~exit_price:200.0))
    (is_some_and (field _positions is_empty))

(* Re-running [close] reports "not held" instead of crediting cash twice. *)
let test_close_twice_rejects _ =
  let once =
    Portfolio_edit.close _held ~as_of:_as_of ~symbol:"AAPL" ~exit_price:200.0
  in
  let twice =
    Result.bind once ~f:(fun t ->
        Portfolio_edit.close t ~as_of:_as_of ~symbol:"AAPL" ~exit_price:200.0)
  in
  assert_that (_msg twice) (is_some_and (contains_substring "is not held"))

let test_close_rejects_non_positive_price _ =
  let result =
    Portfolio_edit.close _held ~as_of:_as_of ~symbol:"AAPL" ~exit_price:0.0
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "exit-price must be positive"))

(* --- adjust ------------------------------------------------------------- *)

(* Raising the stop moves no cash — the common weekly case. *)
let test_adjust_stop_only _ =
  assert_that
    (Result.ok
       (Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL"
          ~stop_price:175.0 ()))
    (is_some_and
       (all_of
          [
            field _cash (float_equal 100_000.0);
            field _positions
              (elements_are
                 [
                   all_of
                     [
                       field _stop (float_equal 175.0);
                       field _shares (equal_to 100);
                     ];
                 ]);
          ]))

(* A trailing stop above the original entry is legal on [adjust] (it is not on
   [record]) — a position in profit runs a breakeven-plus stop. *)
let test_adjust_allows_stop_above_entry _ =
  assert_that
    (Result.ok
       (Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL"
          ~stop_price:195.0 ()))
    (is_some_and
       (field _positions (elements_are [ field _stop (float_equal 195.0) ])))

(* Trimming 40 of 100 shares at 200.0 credits 8_000.0 and leaves 60 held. *)
let test_adjust_trim_credits_and_reduces _ =
  assert_that
    (Result.ok
       (Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL"
          ~trim:{ shares = 40; price = 200.0 }
          ()))
    (is_some_and
       (all_of
          [
            field _cash (float_equal 108_000.0);
            field _positions
              (elements_are
                 [
                   all_of
                     [
                       field _shares (equal_to 60);
                       field _stop (float_equal 168.0);
                     ];
                 ]);
          ]))

(* Both adjustments in one call: cash credited and stop raised together. *)
let test_adjust_trim_and_stop _ =
  assert_that
    (Result.ok
       (Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL"
          ~stop_price:175.0
          ~trim:{ shares = 40; price = 200.0 }
          ()))
    (is_some_and
       (all_of
          [
            field _cash (float_equal 108_000.0);
            field _positions
              (elements_are
                 [
                   all_of
                     [
                       field _shares (equal_to 60);
                       field _stop (float_equal 175.0);
                     ];
                 ]);
          ]))

(* A trim of every share is a close; only [close] may zero a holding. *)
let test_adjust_rejects_full_trim _ =
  let result =
    Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL"
      ~trim:{ shares = 100; price = 200.0 }
      ()
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "must be fewer than the 100 held"))

let test_adjust_rejects_no_op _ =
  let result = Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL" () in
  assert_that (_msg result)
    (is_some_and (contains_substring "needs --stop-price"))

let test_adjust_rejects_unheld_symbol _ =
  let result =
    Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"MSFT" ~stop_price:175.0
      ()
  in
  assert_that (_msg result) (is_some_and (contains_substring "is not held"))

let test_adjust_rejects_non_positive_stop _ =
  let result =
    Portfolio_edit.adjust _held ~as_of:_as_of ~symbol:"AAPL" ~stop_price:0.0 ()
  in
  assert_that (_msg result)
    (is_some_and (contains_substring "stop-price must be positive"))

(* Other holdings are untouched by an edit to one symbol. *)
let test_adjust_leaves_other_positions_alone _ =
  let msft : Live_portfolio.position =
    {
      symbol = "MSFT";
      shares = 50;
      entry_price = 400.0;
      entry_date = _date "2026-06-20";
      stop_price = 370.0;
    }
  in
  let two = { _held with positions = [ _aapl; msft ] } in
  assert_that
    (Result.ok
       (Portfolio_edit.adjust two ~as_of:_as_of ~symbol:"AAPL" ~stop_price:175.0
          ()))
    (is_some_and
       (field _positions
          (elements_are [ field _stop (float_equal 175.0); equal_to msft ])))

let suite =
  "portfolio_edit"
  >::: [
         "record_appends_and_debits" >:: test_record_appends_and_debits;
         "record_normalizes_symbol" >:: test_record_normalizes_symbol;
         "record_rejects_duplicate" >:: test_record_rejects_duplicate;
         "record_rejects_duplicate_other_case"
         >:: test_record_rejects_duplicate_other_case;
         "record_rejects_insufficient_cash"
         >:: test_record_rejects_insufficient_cash;
         "record_rejects_stop_above_entry"
         >:: test_record_rejects_stop_above_entry;
         "record_rejects_non_positive_shares"
         >:: test_record_rejects_non_positive_shares;
         "close_credits_and_removes" >:: test_close_credits_and_removes;
         "close_normalizes_symbol" >:: test_close_normalizes_symbol;
         "close_twice_rejects" >:: test_close_twice_rejects;
         "close_rejects_non_positive_price"
         >:: test_close_rejects_non_positive_price;
         "adjust_stop_only" >:: test_adjust_stop_only;
         "adjust_allows_stop_above_entry"
         >:: test_adjust_allows_stop_above_entry;
         "adjust_trim_credits_and_reduces"
         >:: test_adjust_trim_credits_and_reduces;
         "adjust_trim_and_stop" >:: test_adjust_trim_and_stop;
         "adjust_rejects_full_trim" >:: test_adjust_rejects_full_trim;
         "adjust_rejects_no_op" >:: test_adjust_rejects_no_op;
         "adjust_rejects_unheld_symbol" >:: test_adjust_rejects_unheld_symbol;
         "adjust_rejects_non_positive_stop"
         >:: test_adjust_rejects_non_positive_stop;
         "adjust_leaves_other_positions_alone"
         >:: test_adjust_leaves_other_positions_alone;
       ]

let () = run_test_tt_main suite
