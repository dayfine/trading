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
  sector_exposures : (string * float) list;
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
    ?(positions = 3) ?(sectors = []) ?(sector_exposures = []) () =
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
    sector_exposures;
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
       ~position_count:(equal_to 0) ~sector_counts:__ ~sector_exposures:__)

let test_snapshot_long_only _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0) ] in
  let snap = snapshot ~cash:50000.0 ~positions () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 75000.0) ~cash:__ ~cash_pct:__
       ~long_exposure:(float_equal 25000.0)
       ~long_exposure_pct:(float_equal ~epsilon:1e-6 (1.0 /. 3.0))
       ~short_exposure:(float_equal 0.0) ~short_exposure_pct:__
       ~position_count:(equal_to 2) ~sector_counts:__ ~sector_exposures:__)

let test_snapshot_with_short _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("TSLA", -50.0, 200.0) ] in
  let snap = snapshot ~cash:80000.0 ~positions () in
  assert_that snap
    (match_snapshot ~total_value:(float_equal 85000.0) ~cash:__ ~cash_pct:__
       ~long_exposure:(float_equal 15000.0) ~long_exposure_pct:__
       ~short_exposure:(float_equal 10000.0) ~short_exposure_pct:__
       ~position_count:(equal_to 2) ~sector_counts:__ ~sector_exposures:__)

let test_snapshot_with_sectors _ =
  let positions =
    [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0); ("AMZN", 20.0, 180.0) ]
  in
  let sectors = [ ("AAPL", "Tech"); ("MSFT", "Tech"); ("AMZN", "Tech") ] in
  let snap = snapshot ~cash:50000.0 ~positions ~sectors () in
  assert_that snap
    (match_snapshot ~total_value:__ ~cash:__ ~cash_pct:__ ~long_exposure:__
       ~long_exposure_pct:__ ~short_exposure:__ ~short_exposure_pct:__
       ~position_count:(equal_to 3) ~sector_exposures:__
       ~sector_counts:(fun counts ->
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
       ~position_count:(equal_to 2) ~sector_counts:__ ~sector_exposures:__)

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

(* NaN/inf guards — v7 sweep 2026-05-25 crashed in fold 22 from this path.
   Bare [Float.( <= ) x 0.0] returns false for NaN; values slipped through
   and crashed at [Int.of_float NaN]. Each test below would have crashed
   pre-fix; the guard makes them return zero shares instead. *)
let test_position_size_nan_entry_price _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:Float.nan ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:(float_equal 0.0) ~risk_amount:(float_equal 0.0))

let test_position_size_nan_stop_price _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:50.0 ~stop_price:Float.nan ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:(float_equal 0.0) ~risk_amount:(float_equal 0.0))

let test_position_size_nan_portfolio_value _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:Float.nan
      ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:(float_equal 0.0) ~risk_amount:(float_equal 0.0))

let test_position_size_inf_portfolio_value _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:Float.infinity
      ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:(float_equal 0.0) ~risk_amount:(float_equal 0.0))

let test_position_size_inf_entry_price _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~side:`Long ~entry_price:Float.infinity ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 0) ~position_value:(float_equal 0.0)
       ~position_pct:(float_equal 0.0) ~risk_amount:(float_equal 0.0))

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

(* ---- sizing_cash spendable-cash cap (issue #859 Phase 1, item 3) ---- *)

(* Omitting [sizing_cash] is bit-identical to passing [portfolio_value]: the
   spendable-cash cap equals [portfolio_value / entry_price], always >= both
   fractional caps, so it is never binding. This is the load-bearing default-off
   invariant — every existing golden replays unchanged. *)
let test_sizing_cash_omitted_equals_portfolio_value _ =
  let omitted =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~side:`Long ~entry_price:200.0 ~stop_price:199.0 ()
  in
  let explicit =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~sizing_cash:1_000_000.0 ~side:`Long ~entry_price:200.0 ~stop_price:199.0
      ()
  in
  assert_that omitted (equal_to (explicit : sizing))

(* The basic-sizing case is unchanged when sizing_cash = portfolio_value: 200
   shares (as in test_position_size_basic), proving the cap is inert at the
   default. *)
let test_sizing_cash_at_portfolio_value_inert _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100_000.0
      ~sizing_cash:100_000.0 ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 200) ~position_value:(float_equal 10000.0)
       ~position_pct:(float_equal ~epsilon:1e-6 0.10)
       ~risk_amount:(float_equal 1000.0))

(* When spendable cash is tighter than the risk + exposure caps, it binds. With
   margin on, sizing_cash = available_cash = current_cash - locked_collateral.
   Setup: $100K portfolio_value, but only $5K spendable (the rest locked as
   short collateral). risk-based = floor($1K / $5) = 200 shares ($10K notional),
   exposure/position caps allow more, but $5K / $50 = 100 shares is binding.
   Final = min(200, ..., 100) = 100. *)
let test_sizing_cash_binds_below_risk_cap _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100_000.0
      ~sizing_cash:5_000.0 ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_that result
    (match_sizing ~shares:(equal_to 100) ~position_value:(float_equal 5000.0)
       ~position_pct:(float_equal ~epsilon:1e-6 0.05)
       ~risk_amount:(float_equal 500.0))

(* Plan §1.1 worked example, sizing slice: $10K cash, short 100@$50 locks 150%
   = $7,500 collateral, leaving available_cash = $7,500. A subsequent long at
   $50 with this sizing_cash is capped at floor($7,500 / $50) = 150 shares,
   whereas with the un-netted $10K it could fund 200. Pins that locked short
   collateral no longer inflates long sizing (the Stance-A bug). *)
let test_sizing_cash_caps_long_after_short_collateral_lock _ =
  let with_locked =
    compute_position_size ~config:default_config ~portfolio_value:100_000.0
      ~sizing_cash:7_500.0 ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  let without_lock =
    compute_position_size ~config:default_config ~portfolio_value:100_000.0
      ~sizing_cash:10_000.0 ~side:`Long ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_that
    (with_locked.shares, without_lock.shares)
    (equal_to ((150, 200) : int * int))

(* The spendable-cash cap does not perturb the risk-pct or %-cap math: it only
   bounds shares by cash. A non-binding sizing_cash (>= what the other caps
   allow) leaves the result identical to the legacy per-position-cap case. *)
let test_sizing_cash_non_binding_leaves_caps_intact _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:1_000_000.0
      ~sizing_cash:1_000_000.0 ~side:`Long ~entry_price:200.0 ~stop_price:199.0
      ()
  in
  (* Same as test_position_size_long_capped_by_max_position_pct: per-position
     cap binds at 1,500 shares; sizing_cash ($1M / $200 = 5,000) is looser. *)
  assert_that result
    (all_of
       [
         field (fun (s : sizing) -> s.shares) (equal_to 1500);
         field (fun (s : sizing) -> s.position_value) (float_equal 300_000.0);
       ])

(* snapshot computes sector_exposures from positions, parallel to
   sector_counts. Long + short positions to the same sector aggregate via
   absolute value. *)
let test_snapshot_computes_sector_exposures _ =
  let positions =
    [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0); ("XYZ", -10.0, 100.0) ]
  in
  let sectors = [ ("AAPL", "Tech"); ("MSFT", "Tech"); ("XYZ", "Finance") ] in
  let snap = snapshot ~cash:60_000.0 ~positions ~sectors () in
  assert_that snap
    (match_snapshot ~total_value:__ ~cash:__ ~cash_pct:__ ~long_exposure:__
       ~long_exposure_pct:__ ~short_exposure:__ ~short_exposure_pct:__
       ~position_count:__ ~sector_counts:__ ~sector_exposures:(fun exposures ->
         assert_that
           (List.Assoc.find exposures ~equal:String.equal "Tech")
           (is_some_and (float_equal 25_000.0));
         assert_that
           (List.Assoc.find exposures ~equal:String.equal "Finance")
           (is_some_and (float_equal 1_000.0))))

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
       ~position_count:__ ~sector_exposures:__ ~sector_counts:(fun counts ->
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
  assert_that default_config (equal_to ~cmp:equal_config default_config)

(* Pins the 2026-06-14 promotion (#1557#3): the cash-floor closing-trade
   exemption is ON by default — a correctness invariant (a risk-reducing close
   must never be blocked by the cash floor; the #1553 zombie was the failure of
   the old default-off). A refactor must not silently revert this default. *)
let test_cash_floor_exemption_on_by_default _ =
  assert_that default_config.exempt_closing_trades_from_cash_floor
    (equal_to true)

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
         "position_size_nan_entry_price" >:: test_position_size_nan_entry_price;
         "position_size_nan_stop_price" >:: test_position_size_nan_stop_price;
         "position_size_nan_portfolio_value"
         >:: test_position_size_nan_portfolio_value;
         "position_size_inf_portfolio_value"
         >:: test_position_size_inf_portfolio_value;
         "position_size_inf_entry_price" >:: test_position_size_inf_entry_price;
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
         "sizing_cash_omitted_equals_portfolio_value"
         >:: test_sizing_cash_omitted_equals_portfolio_value;
         "sizing_cash_at_portfolio_value_inert"
         >:: test_sizing_cash_at_portfolio_value_inert;
         "sizing_cash_binds_below_risk_cap"
         >:: test_sizing_cash_binds_below_risk_cap;
         "sizing_cash_caps_long_after_short_collateral_lock"
         >:: test_sizing_cash_caps_long_after_short_collateral_lock;
         "sizing_cash_non_binding_leaves_caps_intact"
         >:: test_sizing_cash_non_binding_leaves_caps_intact;
         "snapshot_computes_sector_exposures"
         >:: test_snapshot_computes_sector_exposures;
         "snapshot_buckets_missing_sectors_as_unknown"
         >:: test_snapshot_buckets_missing_sectors_as_unknown;
         "deriving" >:: test_deriving;
         "cash_floor_exemption_on_by_default"
         >:: test_cash_floor_exemption_on_by_default;
       ]

let () = run_test_tt_main suite
