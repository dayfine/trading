open Core
open OUnit2
open Matchers
open Ishares.Ishares_membership_replay
module Client = Ishares.Ishares_holdings_client

(* ------------------------------------------------------------------------- *)
(* Test fixture builders                                                     *)
(*                                                                           *)
(* The replay layer is pure and operates on parsed [snapshot] values, so the *)
(* tests construct snapshots in-line rather than reading CSV fixtures from   *)
(* disk. PR-A's parser test suite is the place where the CSV-format          *)
(* contract is pinned; here we focus on the diff-and-merge logic.            *)
(* ------------------------------------------------------------------------- *)

(* Default values for [Client.holding] fields we don't care about in the
   replay-layer tests. Keeping the builder thin per
   [.claude/rules/test-patterns.md] §"Test Data Builders". *)
let _holding ~ticker ?(sector = "Information Technology")
    ?(asset_class = "Equity") ?(location = "United States") () : Client.holding
    =
  {
    ticker;
    name = ticker ^ " INC";
    sector;
    asset_class;
    market_value = 100.0;
    weight_pct = 1.0;
    notional_value = 100.0;
    quantity = 1.0;
    price = 100.0;
    location;
    exchange = "NASDAQ";
    currency = "USD";
    fx_rate = 1.0;
    market_currency = "USD";
    accrual_date = "-";
  }

let _date y m d = Date.create_exn ~y ~m ~d

(* Build a [(date, snapshot)] pair from a list of ticker descriptors. Each
   descriptor is [(ticker, sector_opt)]; passing [None] for sector uses the
   default. *)
let _snap (y, m, d) tickers =
  let as_of = _date y m d in
  let holdings =
    List.map tickers ~f:(fun (ticker, sector_opt) ->
        match sector_opt with
        | Some sector -> _holding ~ticker ~sector ()
        | None -> _holding ~ticker ())
  in
  (as_of, { Client.as_of; holdings })

let _t s = (s, None)
let _t_sec s sector = (s, Some sector)

(* ------------------------------------------------------------------------- *)
(* Tests                                                                     *)
(* ------------------------------------------------------------------------- *)

(* Single snapshot ⇒ one tenure record per non-sentinel ticker, with
   first_seen = last_seen = that snapshot's date. *)
let test_single_snapshot_emits_one_record_per_ticker _ =
  let snap = _snap (2020, Month.Jun, 1) [ _t "AAPL"; _t "MSFT" ] in
  let result = replay ~threshold_consecutive_misses:3 [ snap ] in
  assert_that result
    (elements_are
       [
         equal_to
           ({
              ticker = "AAPL";
              first_seen = _date 2020 Month.Jun 1;
              last_seen = _date 2020 Month.Jun 1;
              sector_at_first = "Information Technology";
              index = "IWV";
            }
             : tenure_record);
         equal_to
           ({
              ticker = "MSFT";
              first_seen = _date 2020 Month.Jun 1;
              last_seen = _date 2020 Month.Jun 1;
              sector_at_first = "Information Technology";
              index = "IWV";
            }
             : tenure_record);
       ])

(* Two consecutive snapshots with overlapping tickers ⇒ tenure spans both
   dates for the shared ticker, and a new tenure opens for the ticker
   appearing only in snap 2. *)
let test_two_snapshots_overlap_spans_dates _ =
  let snaps =
    [
      _snap (2020, Month.Jun, 1) [ _t "AAPL"; _t "MSFT" ];
      _snap (2020, Month.Jun, 2) [ _t "AAPL"; _t "GOOG" ];
    ]
  in
  let result = replay ~threshold_consecutive_misses:3 snaps in
  (* MSFT is absent in snap 2 (1 miss) which is below threshold=3, so its
     tenure stays open and is emitted at flush time. AAPL is observed in
     both, so last_seen advances. GOOG opens fresh in snap 2. All three
     flush-time records are sorted by (first_seen, ticker). *)
  assert_that result
    (elements_are
       [
         all_of
           [
             field (fun (r : tenure_record) -> r.ticker) (equal_to "AAPL");
             field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 1));
             field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 2));
           ];
         all_of
           [
             field (fun (r : tenure_record) -> r.ticker) (equal_to "MSFT");
             field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 1));
             field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 1));
           ];
         all_of
           [
             field (fun (r : tenure_record) -> r.ticker) (equal_to "GOOG");
             field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 2));
             field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 2));
           ];
       ])

(* Single-snapshot data glitch (ticker absent for 1 snapshot, then back)
   must NOT split the tenure when threshold >= 2. The original
   first_seen/last_seen progression is preserved across the gap. *)
let test_single_miss_below_threshold_keeps_tenure_open _ =
  let snaps =
    [
      _snap (2020, Month.Jun, 1) [ _t "AAPL" ];
      _snap (2020, Month.Jun, 2) [ _t "MSFT" ];
      (* AAPL absent — 1 miss *)
      _snap (2020, Month.Jun, 3) [ _t "AAPL" ];
    ]
  in
  let result = replay ~threshold_consecutive_misses:3 snaps in
  let aapl = List.find result ~f:(fun r -> String.equal r.ticker "AAPL") in
  assert_that aapl
    (is_some_and
       (all_of
          [
            field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 1));
            field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 3));
          ]))

(* Removal confirmed after 3 consecutive misses. The tenure is closed at the
   snapshot that bumps the streak to 3, and last_seen retains the last
   *observed* date — not the closure date. *)
let test_three_consecutive_misses_closes_tenure_at_last_seen _ =
  let snaps =
    [
      _snap (2020, Month.Jun, 1) [ _t "AAPL"; _t "MSFT" ];
      _snap (2020, Month.Jun, 2) [ _t "MSFT" ];
      (* AAPL miss 1 *)
      _snap (2020, Month.Jun, 3) [ _t "MSFT" ];
      (* AAPL miss 2 *)
      _snap (2020, Month.Jun, 4) [ _t "MSFT" ];
      (* AAPL miss 3 → close *)
    ]
  in
  let result = replay ~threshold_consecutive_misses:3 snaps in
  let aapl = List.find result ~f:(fun r -> String.equal r.ticker "AAPL") in
  assert_that aapl
    (is_some_and
       (all_of
          [
            field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 1));
            field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 1));
          ]))

(* Era mixing: snapshot 1 (2007) has empty sectors ("-"); snapshot 2 (2012)
   has populated sectors. The replay must pin [sector_at_first] to whatever
   the FIRST observation recorded — even if it's the pre-2009 sentinel
   string. *)
let test_sector_at_first_is_taken_from_first_observation _ =
  let snaps =
    [
      _snap (2007, Month.Dec, 31) [ _t_sec "AAPL" "-" ];
      _snap (2012, Month.Apr, 30) [ _t_sec "AAPL" "Information Technology" ];
    ]
  in
  let result = replay ~threshold_consecutive_misses:3 snaps in
  assert_that result
    (elements_are
       [
         all_of
           [
             field (fun (r : tenure_record) -> r.ticker) (equal_to "AAPL");
             field (fun r -> r.sector_at_first) (equal_to "-");
             field (fun r -> r.first_seen) (equal_to (_date 2007 Month.Dec 31));
             field (fun r -> r.last_seen) (equal_to (_date 2012 Month.Apr 30));
             field (fun r -> r.index) (equal_to "IWV");
           ];
       ])

(* Threshold parameterization: with threshold=1 the same "1 miss" sequence
   that previously kept the tenure open instead closes it at the first
   miss. The re-appearance of the ticker after closure opens a brand-new
   tenure with a later [first_seen]. *)
let test_threshold_one_closes_on_single_miss _ =
  let snaps =
    [
      _snap (2020, Month.Jun, 1) [ _t "AAPL" ];
      _snap (2020, Month.Jun, 2) [ _t "MSFT" ];
      (* AAPL miss 1 → closes at threshold=1 *)
      _snap (2020, Month.Jun, 3) [ _t "AAPL" ];
      (* Re-opens a fresh tenure *)
    ]
  in
  let result = replay ~threshold_consecutive_misses:1 snaps in
  let aapl_records =
    List.filter result ~f:(fun r -> String.equal r.ticker "AAPL")
  in
  assert_that aapl_records
    (elements_are
       [
         all_of
           [
             field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 1));
             field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 1));
           ];
         all_of
           [
             field (fun r -> r.first_seen) (equal_to (_date 2020 Month.Jun 3));
             field (fun r -> r.last_seen) (equal_to (_date 2020 Month.Jun 3));
           ];
       ])

(* Un-tickered escrow positions ([ticker = "-"]) must be dropped before
   replay per plan §2.3.3; they never appear in the output. *)
let test_untickered_rows_are_dropped _ =
  let snap = _snap (2007, Month.Dec, 31) [ _t "AAPL"; _t "-" ] in
  let result = replay ~threshold_consecutive_misses:3 [ snap ] in
  let tickers = List.map result ~f:(fun r -> r.ticker) in
  assert_that tickers (elements_are [ equal_to "AAPL" ])

(* Empty input list ⇒ empty output. *)
let test_empty_input _ =
  let result = replay ~threshold_consecutive_misses:3 [] in
  assert_that result (size_is 0)

(* The [?index] override is plumbed through to every emitted record. *)
let test_custom_index_label _ =
  let snap = _snap (2020, Month.Jun, 1) [ _t "AAPL" ] in
  let result = replay ~index:"IWB" ~threshold_consecutive_misses:3 [ snap ] in
  assert_that result
    (elements_are
       [ field (fun (r : tenure_record) -> r.index) (equal_to "IWB") ])

let suite =
  "ishares_membership_replay_test"
  >::: [
         "single_snapshot_emits_one_record_per_ticker"
         >:: test_single_snapshot_emits_one_record_per_ticker;
         "two_snapshots_overlap_spans_dates"
         >:: test_two_snapshots_overlap_spans_dates;
         "single_miss_below_threshold_keeps_tenure_open"
         >:: test_single_miss_below_threshold_keeps_tenure_open;
         "three_consecutive_misses_closes_tenure_at_last_seen"
         >:: test_three_consecutive_misses_closes_tenure_at_last_seen;
         "sector_at_first_is_taken_from_first_observation"
         >:: test_sector_at_first_is_taken_from_first_observation;
         "threshold_one_closes_on_single_miss"
         >:: test_threshold_one_closes_on_single_miss;
         "untickered_rows_are_dropped" >:: test_untickered_rows_are_dropped;
         "empty_input" >:: test_empty_input;
         "custom_index_label" >:: test_custom_index_label;
       ]

let () = run_test_tt_main suite
