open OUnit2
open Core
open Portfolio_risk
open Matchers

(* Re-declare record types for exhaustive ppx-generated matchers.
   If the production type adds/removes a field, this fails to compile. *)
type snapshot = Portfolio_risk.portfolio_snapshot = {
  total_value : float;
  cash : float;
  cash_pct : float;
  long_exposure : float;
  long_exposure_pct : float;
  short_exposure : float;
  short_exposure_pct : float;
  position_count : int;
  sector_counts : (string * int) list;
}
[@@deriving test_matcher]

type sizing = Portfolio_risk.sizing_result = {
  shares : int;
  position_value : float;
  position_pct : float;
  risk_amount : float;
}
[@@deriving test_matcher]

(* ---- Test helpers ---- *)

(* Directly constructs a portfolio_snapshot for limit-check tests, bypassing
   the snapshot functions. This lets us set arbitrary exposure values without
   needing a real portfolio + trade history. *)
let make_snapshot ?(cash = 80000.0) ?(long_exp = 15000.0) ?(short_exp = 0.0)
    ?(positions = 3) ?(sectors = []) () =
  let total = cash +. long_exp -. short_exp in
  {
    total_value = total;
    cash;
    cash_pct = (if Float.( > ) total 0.0 then cash /. total else 0.0);
    long_exposure = long_exp;
    long_exposure_pct =
      (if Float.( > ) total 0.0 then long_exp /. total else 0.0);
    short_exposure = short_exp;
    short_exposure_pct =
      (if Float.( > ) total 0.0 then short_exp /. total else 0.0);
    position_count = positions;
    sector_counts = sectors;
  }

let make_trade ~symbol ~(side : Trading_base.Types.side) ~quantity ~price =
  Trading_base.Types.
    {
      id = symbol ^ "_trade";
      order_id = symbol ^ "_order";
      symbol;
      side;
      quantity;
      price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }

let apply_trades_exn portfolio trades =
  match Trading_portfolio.Portfolio.apply_trades portfolio trades with
  | Ok p -> p
  | Error err -> assert_failure (Status.show err)

(* ---- Snapshot tests ---- *)

let test_snapshot_empty _ =
  let snap = snapshot ~cash:100000.0 ~positions:[] () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 100000.0)
       ~cash:(float_equal 100000.0) ~cash_pct:(float_equal 1.0)
       ~long_exposure:(float_equal 0.0) ~long_exposure_pct:__
       ~short_exposure:(float_equal 0.0) ~short_exposure_pct:__
       ~position_count:(equal_to 0) ~sector_counts:__)

let test_snapshot_long_only _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0) ] in
  let snap = snapshot ~cash:50000.0 ~positions () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 75000.0) ~cash:__ ~cash_pct:__
       ~long_exposure:(float_equal 25000.0)
       ~long_exposure_pct:(float_equal ~epsilon:1e-6 (1.0 /. 3.0))
       ~short_exposure:(float_equal 0.0) ~short_exposure_pct:__
       ~position_count:(equal_to 2) ~sector_counts:__)

let test_snapshot_with_short _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("TSLA", -50.0, 200.0) ] in
  let snap = snapshot ~cash:80000.0 ~positions () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 85000.0) ~cash:__ ~cash_pct:__
       ~long_exposure:(float_equal 15000.0) ~long_exposure_pct:__
       ~short_exposure:(float_equal 10000.0) ~short_exposure_pct:__
       ~position_count:(equal_to 2) ~sector_counts:__)

let test_snapshot_with_sectors _ =
  let positions =
    [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0); ("AMZN", 20.0, 180.0) ]
  in
  let sectors = [ ("AAPL", "Tech"); ("MSFT", "Tech"); ("AMZN", "Tech") ] in
  let snap = snapshot ~cash:50000.0 ~positions ~sectors () in
  assert_that snap
    (match_snapshot ~total_value:__ ~cash:__ ~cash_pct:__ ~long_exposure:__
       ~long_exposure_pct:__ ~short_exposure:__ ~short_exposure_pct:__
       ~position_count:(equal_to 3) ~sector_counts:(fun counts ->
         assert_that
           (List.Assoc.find counts ~equal:String.equal "Tech")
           (is_some_and (equal_to 3))))

(* Tests snapshot_of_portfolio, which derives cash and positions from an
   existing Portfolio.t rather than raw tuples. *)
let test_snapshot_of_portfolio _ =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:100000.0 () |> fun p ->
    apply_trades_exn p
      [
        make_trade ~symbol:"AAPL" ~side:Buy ~quantity:100.0 ~price:100.0;
        make_trade ~symbol:"MSFT" ~side:Buy ~quantity:50.0 ~price:100.0;
      ]
  in
  (* cash after trades: 100000 - 10000 - 5000 = 85000
     long exposure at current prices: 100*150 + 50*200 = 15000 + 10000 = 25000
     total: 85000 + 25000 = 110000 *)
  let prices = [ ("AAPL", 150.0); ("MSFT", 200.0) ] in
  let snap = snapshot_of_portfolio ~portfolio ~prices () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 110000.0)
       ~cash:(float_equal 85000.0) ~cash_pct:__
       ~long_exposure:(float_equal 25000.0) ~long_exposure_pct:__
       ~short_exposure:(float_equal 0.0) ~short_exposure_pct:__
       ~position_count:(equal_to 2) ~sector_counts:__)

(* ---- Position sizing tests ---- *)

let test_position_size_basic _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  (* risk = 1000, risk_per_share = 5, shares = 200, position_value = 10000 *)
  assert_that result
    (match_sizing ~shares:(equal_to 200) ~position_value:(float_equal 10000.0)
       ~position_pct:(float_equal ~epsilon:1e-6 0.10)
       ~risk_amount:(float_equal 1000.0))

let test_position_size_rounds_down _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:47.0 ~stop_price:44.50 ()
  in
  (* risk = 1000, risk_per_share = 2.5, shares = floor(400) = 400 *)
  assert_that result
    (match_sizing ~shares:(equal_to 400) ~position_value:__ ~position_pct:__
       ~risk_amount:__)

let test_position_size_invalid_stop _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:50.0 ~stop_price:50.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:__ ~risk_amount:__)

let test_position_size_big_winner _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ~big_winner:true ()
  in
  (* risk = 1500 (1% * 1.5x), risk_per_share = 5, shares = 300 *)
  assert_that result
    (match_sizing ~shares:(equal_to 300) ~position_value:__ ~position_pct:__
       ~risk_amount:__)

(* G7 regression — short with very tight stop must not size to >100% of
   portfolio. Pre-G7: risk-budget formula alone produces 12,191 shares for a
   $1M portfolio at risk_pct=0.01 with 0.82 risk_per_share → $1.238M position
   (124% of portfolio). Post-G7: capped by max_short_exposure_pct = 0.30.

   max_position_pct=0.20 cap landed 2026-05-01 — re-pinned: per-position cap
   (20% × $1M = $200K) is now tighter than the side-exposure cap (30% × $1M
   = $300K), so floor($200K / $101.59) = 1,968 shares is the binding limit. *)
let test_position_size_short_capped_by_max_short_exposure _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~side:`Short ~entry_price:101.59 ~stop_price:102.41 ()
  in
  (* Per-position cap binds: floor($200K / $101.59) = 1,968 shares. *)
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 1968);
         field
           (fun (s : sizing) -> s.position_value)
           (le (module Float_ord) 200_000.0);
         field (fun (s : sizing) -> s.position_pct) (le (module Float_ord) 0.20);
       ])

(* Symmetric long-side check: a long with a very tight stop must not exceed
   the binding cap.

   max_position_pct=0.20 cap landed 2026-05-01 — re-pinned: per-position cap
   (20% × $1M = $200K) is tighter than max_long_exposure_pct = 0.90, so
   $200K / $100 = 2,000 shares is the binding limit. *)
let test_position_size_long_capped_by_max_long_exposure _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~side:`Long ~entry_price:100.0 ~stop_price:99.0 ()
  in
  (* Per-position long cap binds: 0.30 * $1M / $100 = 3,000 shares.
     (Asymmetric cap: long uses 0.30 default per 2026-05-01.) *)
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 3000);
         field
           (fun (s : sizing) -> s.position_value)
           (le (module Float_ord) 300_000.0);
         field (fun (s : sizing) -> s.position_pct) (le (module Float_ord) 0.30);
       ])

(* Cap is configurable: tightening max_short_exposure_pct further reduces the
   sized shares proportionally. *)
let test_position_size_short_cap_is_configurable _ =
  let config = { default_config with max_short_exposure_pct = 0.10 } in
  let result =
    compute_position_size ~config ~portfolio_value:1_000_000.0 ~side:`Short
      ~entry_price:100.0 ~stop_price:101.0 ()
  in
  (* max position_value = 0.10 * $1M = $100K → max shares = 1,000. *)
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 1000);
         field (fun (s : sizing) -> s.position_pct) (le (module Float_ord) 0.10);
       ])

(* Long-side per-position cap binds. With risk_per_trade_pct=0.01,
   portfolio_value=$1M, entry=$200, stop=$199:
     - risk-based: dollar_risk=$10K, risk_per_share=$1 → 10,000 shares
     - side-exposure cap (long 90%): $900K / $200 = 4,500 shares
     - per-position cap (long 30%): $300K / $200 = 1,500 shares (binds)
   Final shares = min(10000, 4500, 1500) = 1,500. *)
let test_position_size_long_capped_by_max_position_pct _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~side:`Long ~entry_price:200.0 ~stop_price:199.0 ()
  in
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 1500);
         field (fun (s : sizing) -> s.position_value) (float_equal 300_000.0);
         field
           (fun (s : sizing) -> s.position_pct)
           (float_equal ~epsilon:1e-6 0.30);
       ])

(* Short-side per-position cap binds. Same setup but on the short side and
   stop above entry:
     - risk-based: 10,000 shares
     - side-exposure cap (short 30%): $300K / $200 = 1,500 shares
     - per-position cap (short 20%): $200K / $200 = 1,000 shares (binds)
   Final shares = min(10000, 1500, 1000) = 1,000. *)
let test_position_size_short_capped_by_max_position_pct _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~side:`Short ~entry_price:200.0 ~stop_price:201.0 ()
  in
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 1000);
         field (fun (s : sizing) -> s.position_value) (float_equal 200_000.0);
         field
           (fun (s : sizing) -> s.position_pct)
           (float_equal ~epsilon:1e-6 0.20);
       ])

(* When the risk-based sizing is already below the exposure cap, the cap is
   inert and the original sizing stands. *)
let test_position_size_below_cap_unaffected _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100_000.0
      ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  (* shares = 200, position_value = $10K = 10% of portfolio — well below
     max_long_exposure_pct = 0.90, so cap is inert. *)
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 200);
         field (fun (s : sizing) -> s.position_value) (float_equal 10_000.0);
         field (fun (s : sizing) -> s.risk_amount) (float_equal 1000.0);
       ])

(* ---- Limit check tests ---- *)

let test_check_limits_ok _ =
  let snap = make_snapshot () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_that result (equal_to (Result.Ok ()))

let test_check_limits_max_positions _ =
  let snap = make_snapshot ~positions:20 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_that result (equal_to (Result.Error [ Max_positions_exceeded 20 ]))

let test_check_limits_long_exposure _ =
  (* long_exp=85000, cash=15000, total=100000; adding 10000 long pushes to 95% *)
  let snap = make_snapshot ~cash:15000.0 ~long_exp:85000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:10000.0 ~proposed_sector:"Tech"
  in
  assert_that result
    (equal_to
       (Result.Error [ Long_exposure_exceeded 0.95; Cash_below_minimum 0.05 ]))

let test_check_limits_cash_minimum _ =
  (* cash=12000, long_exp=88000, total=100000; adding 5000 leaves 7% cash *)
  let snap = make_snapshot ~cash:12000.0 ~long_exp:88000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_that result
    (equal_to
       (Result.Error [ Long_exposure_exceeded 0.93; Cash_below_minimum 0.07 ]))

let test_check_limits_sector_concentration _ =
  let sectors = [ ("Tech", 5) ] in
  let snap = make_snapshot ~sectors () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_that result
    (equal_to (Result.Error [ Sector_concentration ("Tech", 6) ]))

let test_check_limits_multiple_violations _ =
  (* positions=20 (max), cash=5000, long=95000; adding 10000 long hits 3 limits *)
  let snap = make_snapshot ~positions:20 ~cash:5000.0 ~long_exp:95000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:10000.0 ~proposed_sector:"Tech"
  in
  assert_that result
    (equal_to
       (Result.Error
          [
            Max_positions_exceeded 20;
            Long_exposure_exceeded 1.05;
            Cash_below_minimum (-0.05);
          ]))

let test_check_limits_short_side _ =
  (* short_exp=28000, cash=80000, long=0, total=52000; adding 10000 short -> 73% *)
  let snap = make_snapshot ~short_exp:28000.0 ~long_exp:0.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Short
      ~proposed_value:10000.0 ~proposed_sector:"Finance"
  in
  assert_that result
    (equal_to (Result.Error [ Short_exposure_exceeded (38000.0 /. 52000.0) ]))

(* ---- Unknown-sector bucket tests ---- *)

(* With the default config (max_unknown_sector_positions = 2), a proposed
   position whose sector is empty is allowed as long as the unknown bucket
   has fewer than 2 entries already. *)
let test_check_limits_unknown_sector_allowed _ =
  let snap = make_snapshot ~sectors:[ ("", 1) ] () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:""
  in
  assert_that result (equal_to (Result.Ok ()))

(* Proposing a third unknown-sector position violates the cap with the
   dedicated Unknown_sector_exceeded violation -- not Sector_concentration. *)
let test_check_limits_unknown_sector_exceeded _ =
  let snap = make_snapshot ~sectors:[ ("", 2) ] () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:""
  in
  assert_that result (equal_to (Result.Error [ Unknown_sector_exceeded 3 ]))

(* A named-sector position is governed by max_sector_concentration (default 5),
   not the unknown-sector cap -- even if the portfolio also has a full unknown
   bucket, a new "Tech" position with count 4 -> 5 must still be accepted. *)
let test_check_limits_named_sector_unaffected_by_unknown_cap _ =
  let snap = make_snapshot ~sectors:[ ("", 5); ("Tech", 4) ] () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_that result (equal_to (Result.Ok ()))

(* The unknown-sector cap is configurable -- raising it lets more unknown
   positions through. *)
let test_check_limits_unknown_sector_configurable _ =
  let config = { default_config with max_unknown_sector_positions = 4 } in
  let snap = make_snapshot ~sectors:[ ("", 3) ] () in
  let result =
    check_limits ~config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:""
  in
  assert_that result (equal_to (Result.Ok ()))

(* snapshot derives sector counts from positions. Positions whose symbol is
   absent from the sectors list are bucketed under the empty-string key. *)
let test_snapshot_buckets_missing_sectors_as_unknown _ =
  let positions =
    [ ("AAPL", 100.0, 150.0); ("UNK", 10.0, 50.0); ("UNK2", 5.0, 100.0) ]
  in
  let sectors = [ ("AAPL", "Tech") ] in
  let snap = snapshot ~cash:50000.0 ~positions ~sectors () in
  assert_that snap
    (match_snapshot ~total_value:__ ~cash:__ ~cash_pct:__ ~long_exposure:__
       ~long_exposure_pct:__ ~short_exposure:__ ~short_exposure_pct:__
       ~position_count:__ ~sector_counts:(fun counts ->
         assert_that
           (List.Assoc.find counts ~equal:String.equal "")
           (is_some_and (equal_to 2));
         assert_that
           (List.Assoc.find counts ~equal:String.equal "Tech")
           (is_some_and (equal_to 1))))

let test_deriving _ =
  let _ = show_portfolio_snapshot (make_snapshot ()) in
  let _ =
    show_sizing_result
      {
        shares = 100;
        position_value = 5000.0;
        position_pct = 0.05;
        risk_amount = 500.0;
      }
  in
  let _ = show_config default_config in
  let _ = show_limit_violation (Max_positions_exceeded 20) in
  assert_that default_config (equal_to ~cmp:equal_config default_config)

let suite =
  "portfolio_risk"
  >::: [
         "snapshot_empty" >:: test_snapshot_empty;
         "snapshot_long_only" >:: test_snapshot_long_only;
         "snapshot_with_short" >:: test_snapshot_with_short;
         "snapshot_with_sectors" >:: test_snapshot_with_sectors;
         "snapshot_of_portfolio" >:: test_snapshot_of_portfolio;
         "position_size_basic" >:: test_position_size_basic;
         "position_size_rounds_down" >:: test_position_size_rounds_down;
         "position_size_invalid_stop" >:: test_position_size_invalid_stop;
         "position_size_big_winner" >:: test_position_size_big_winner;
         "position_size_short_capped_by_max_short_exposure"
         >:: test_position_size_short_capped_by_max_short_exposure;
         "position_size_long_capped_by_max_long_exposure"
         >:: test_position_size_long_capped_by_max_long_exposure;
         "position_size_short_cap_is_configurable"
         >:: test_position_size_short_cap_is_configurable;
         "position_size_long_capped_by_max_position_pct"
         >:: test_position_size_long_capped_by_max_position_pct;
         "position_size_short_capped_by_max_position_pct"
         >:: test_position_size_short_capped_by_max_position_pct;
         "position_size_below_cap_unaffected"
         >:: test_position_size_below_cap_unaffected;
         "check_limits_ok" >:: test_check_limits_ok;
         "check_limits_max_positions" >:: test_check_limits_max_positions;
         "check_limits_long_exposure" >:: test_check_limits_long_exposure;
         "check_limits_cash_minimum" >:: test_check_limits_cash_minimum;
         "check_limits_sector_concentration"
         >:: test_check_limits_sector_concentration;
         "check_limits_multiple_violations"
         >:: test_check_limits_multiple_violations;
         "check_limits_short_side" >:: test_check_limits_short_side;
         "check_limits_unknown_sector_allowed"
         >:: test_check_limits_unknown_sector_allowed;
         "check_limits_unknown_sector_exceeded"
         >:: test_check_limits_unknown_sector_exceeded;
         "check_limits_named_sector_unaffected_by_unknown_cap"
         >:: test_check_limits_named_sector_unaffected_by_unknown_cap;
         "check_limits_unknown_sector_configurable"
         >:: test_check_limits_unknown_sector_configurable;
         "snapshot_buckets_missing_sectors_as_unknown"
         >:: test_snapshot_buckets_missing_sectors_as_unknown;
         "deriving" >:: test_deriving;
       ]

let () = run_test_tt_main suite
