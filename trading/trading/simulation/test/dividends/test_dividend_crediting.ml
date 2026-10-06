(** Tests for {!Trading_simulation_dividends.Dividend_crediting} (issue #3137
    part 2): longs receive and shorts pay [quantity * unadjusted_amount] on the
    ex-date; only positions held when the ex-date step starts are paid; an
    ex-date between two steps is credited on the next step; a [None] amount is
    skipped and counted (never filled from [adjusted_amount]); a missing file is
    counted once; nothing before [start_date]; a malformed file fails the step;
    and [of_data_dir] reads the real on-disk [dividends.csv]. *)

open OUnit2
open Core
open Matchers
module Dividend_crediting = Trading_simulation_dividends.Dividend_crediting
module Portfolio = Trading_portfolio.Portfolio

let _date = Date.of_string
let _cash = 1_000_000.0
let _ok_exn = function Ok v -> v | Error e -> failwith (Status.show e)

let _trade ~side ~symbol ~quantity : Trading_base.Types.trade =
  {
    id = "t-" ^ symbol;
    order_id = "o-" ^ symbol;
    symbol;
    side;
    quantity;
    price = 50.0;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

(* A portfolio holding [qty] shares of each listed symbol (negative = short),
   all bought / sold at $50. *)
let _holding positions =
  List.fold positions ~init:(Portfolio.create ~initial_cash:_cash ())
    ~f:(fun p (symbol, qty) ->
      let side = if Float.(qty > 0.0) then Trading_base.Types.Buy else Sell in
      _ok_exn
        (Portfolio.apply_single_trade p
           (_trade ~side ~symbol ~quantity:(Float.abs qty))))

let _div ?(adjusted = 0.0) ex_date amount : Corporate_actions.dividend =
  {
    ex_date = _date ex_date;
    unadjusted_amount = amount;
    adjusted_amount = adjusted;
  }

(* An in-memory loader: [table] maps a symbol to its dividends; any other
   symbol has no file. [calls] counts loads per symbol. *)
let _loader ?(calls = String.Table.create ()) table symbol =
  Hashtbl.incr calls symbol;
  match List.Assoc.find table symbol ~equal:String.equal with
  | Some divs -> Ok divs
  | None -> Status.error_not_found (symbol ^ ": not fetched")

let _crediting ?calls ?(start_date = "2024-01-01") table =
  Dividend_crediting.create ~load:(_loader ?calls table)
    ~start_date:(_date start_date)

(* Run [steps] (date, portfolio-at-step-start) through one crediting state and
   return the cash change each step applied. *)
let _cash_changes t steps =
  List.map steps ~f:(fun (date, p) ->
      let%map.Result p' =
        Dividend_crediting.step (Some t) ~date:(_date date) p
      in
      p'.Portfolio.current_cash -. p.Portfolio.current_cash)
  |> Result.all

(* The step results, then the totals they left. Sequenced with [let]: a tuple
   evaluates right to left, so the totals would be read before any step ran. *)
let _changes_and_totals t steps =
  let changes = _cash_changes t steps in
  (changes, Dividend_crediting.totals t)

let _aapl_quarterly = [ ("AAPL", [ _div "2024-01-03" (Some 0.25) ]) ]

let test_long_credited_on_ex_date _ =
  let t = _crediting _aapl_quarterly in
  let p = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (_changes_and_totals t
       [ ("2024-01-02", p); ("2024-01-03", p); ("2024-01-04", p) ])
    (pair
       (is_ok_and_holds
          (elements_are [ float_equal 0.0; float_equal 25.0; float_equal 0.0 ]))
       (equal_to
          ({
             long_income = 25.0;
             short_paid = 0.0;
             skipped_no_amount = 0;
             missing_files = 0;
           }
            : Dividend_crediting.totals)))

let test_short_charged_on_ex_date _ =
  let t = _crediting [ ("XYZ", [ _div "2024-01-03" (Some 0.5) ]) ] in
  let p = _holding [ ("XYZ", -40.0) ] in
  assert_that
    (_changes_and_totals t [ ("2024-01-03", p) ])
    (pair
       (is_ok_and_holds (elements_are [ float_equal (-20.0) ]))
       (all_of
          [
            field
              (fun (x : Dividend_crediting.totals) -> x.short_paid)
              (float_equal 20.0);
            field
              (fun (x : Dividend_crediting.totals) -> x.long_income)
              (float_equal 0.0);
          ]))

(* Bought after the ex-date step: not held when that step started. *)
let test_opened_after_ex_date_gets_nothing _ =
  let t = _crediting _aapl_quarterly in
  let flat = _holding [] and held = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (_cash_changes t [ ("2024-01-03", flat); ("2024-01-04", held) ])
    (is_ok_and_holds (elements_are [ float_equal 0.0; float_equal 0.0 ]))

(* Sold before the ex-date step: no longer held when that step started. *)
let test_closed_before_ex_date_gets_nothing _ =
  let t = _crediting _aapl_quarterly in
  let held = _holding [ ("AAPL", 100.0) ] and flat = _holding [] in
  assert_that
    (_cash_changes t [ ("2024-01-02", held); ("2024-01-03", flat) ])
    (is_ok_and_holds (elements_are [ float_equal 0.0; float_equal 0.0 ]))

(* Ex-date Saturday 2024-01-06 with steps on Friday and Monday only: credited
   on Monday, once. *)
let test_non_trading_ex_date_credited_next_step _ =
  let t = _crediting [ ("AAPL", [ _div "2024-01-06" (Some 0.25) ]) ] in
  let p = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (_cash_changes t
       [ ("2024-01-05", p); ("2024-01-08", p); ("2024-01-09", p) ])
    (is_ok_and_holds
       (elements_are [ float_equal 0.0; float_equal 25.0; float_equal 0.0 ]))

(* [unadjusted_amount = None] credits nothing even though [adjusted_amount] is
   set, and is counted; the special in the same file is credited normally. *)
let test_none_amount_skipped_not_adjusted _ =
  let t =
    _crediting
      [
        ( "AAPL",
          [ _div ~adjusted:0.3 "2024-01-03" None; _div "2024-01-04" (Some 2.0) ]
        );
      ]
  in
  let p = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (_changes_and_totals t [ ("2024-01-03", p); ("2024-01-04", p) ])
    (pair
       (is_ok_and_holds (elements_are [ float_equal 0.0; float_equal 200.0 ]))
       (all_of
          [
            field
              (fun (x : Dividend_crediting.totals) -> x.skipped_no_amount)
              (equal_to 1);
            field
              (fun (x : Dividend_crediting.totals) -> x.long_income)
              (float_equal 200.0);
          ]))

(* A held symbol with no file credits nothing, is counted once and is loaded
   once across steps. *)
let test_missing_file_counted_once _ =
  let calls = String.Table.create () in
  let t = _crediting ~calls [] in
  let p = _holding [ ("NOFILE", 10.0) ] in
  assert_that
    (let changes, totals =
       _changes_and_totals t [ ("2024-01-02", p); ("2024-01-03", p) ]
     in
     (changes, totals.missing_files, Hashtbl.find calls "NOFILE"))
    (all_of
       [
         field
           (fun (c, _, _) -> c)
           (is_ok_and_holds (elements_are [ float_equal 0.0; float_equal 0.0 ]));
         field (fun (_, m, _) -> m) (equal_to 1);
         field (fun (_, _, n) -> n) (is_some_and (equal_to 1));
       ])

(* Ex-dates before [start_date] (warmup) are never credited. *)
let test_before_start_date_not_credited _ =
  let t = _crediting ~start_date:"2024-01-04" _aapl_quarterly in
  let p = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (_cash_changes t [ ("2024-01-03", p); ("2024-01-04", p) ])
    (is_ok_and_holds (elements_are [ float_equal 0.0; float_equal 0.0 ]))

let test_unreadable_file_fails_step _ =
  let t =
    Dividend_crediting.create
      ~load:(fun _ -> Status.error_invalid_argument "bad row")
      ~start_date:(_date "2024-01-01")
  in
  assert_that
    (Dividend_crediting.step (Some t) ~date:(_date "2024-01-02")
       (_holding [ ("AAPL", 1.0) ]))
    (is_error_with Status.Invalid_argument)

let test_none_is_identity _ =
  let p = _holding [ ("AAPL", 100.0) ] in
  assert_that
    (Dividend_crediting.step None ~date:(_date "2024-01-03") p)
    (is_ok_and_holds (equal_to ~cmp:Portfolio.equal p))

(* [of_data_dir] reads the file the corporate-actions writer produced. *)
let test_of_data_dir_reads_store _ =
  let dir = Filename_unix.temp_dir "dividend_crediting" "" in
  let data_dir = Fpath.v dir in
  _ok_exn
    (Corporate_actions.write_dividends ~data_dir "AAPL"
       [ _div ~adjusted:0.25 "2024-01-03" (Some 0.25) ]);
  let t =
    Dividend_crediting.of_data_dir ~data_dir ~start_date:(_date "2024-01-01")
  in
  let p = _holding [ ("AAPL", 100.0); ("MSFT", 10.0) ] in
  let changes = _cash_changes t [ ("2024-01-03", p) ] in
  ignore (Core_unix.system (sprintf "rm -rf %s" (Filename.quote dir)));
  assert_that
    (changes, Dividend_crediting.totals t)
    (pair
       (is_ok_and_holds (elements_are [ float_equal 25.0 ]))
       (field
          (fun (x : Dividend_crediting.totals) -> x.missing_files)
          (equal_to 1)))

let suite =
  "dividend_crediting"
  >::: [
         "long credited on ex-date" >:: test_long_credited_on_ex_date;
         "short charged on ex-date" >:: test_short_charged_on_ex_date;
         "opened after ex-date gets nothing"
         >:: test_opened_after_ex_date_gets_nothing;
         "closed before ex-date gets nothing"
         >:: test_closed_before_ex_date_gets_nothing;
         "non-trading ex-date credited next step"
         >:: test_non_trading_ex_date_credited_next_step;
         "None amount skipped, not adjusted"
         >:: test_none_amount_skipped_not_adjusted;
         "missing file counted once" >:: test_missing_file_counted_once;
         "before start date not credited"
         >:: test_before_start_date_not_credited;
         "unreadable file fails the step" >:: test_unreadable_file_fails_step;
         "None crediting is identity" >:: test_none_is_identity;
         "of_data_dir reads the store" >:: test_of_data_dir_reads_store;
       ]

let () = run_test_tt_main suite
