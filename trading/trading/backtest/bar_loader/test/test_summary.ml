(** Integration tests for Bar_loader — 3b (Summary tier).

    These tests exercise the loader's tier bookkeeping end-to-end: promote to
    Summary from a CSV fixture, verify the indicator scalars land in the
    [get_summary] record, check idempotency, demote and observe the drop. The
    pure math is covered by [test_summary_compute.ml] — here we focus on the
    plumbing. *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* Re-declare the records here with [@@deriving test_matcher] so
   ppx_test_matcher generates exhaustive [match_<name>] helpers. The
   [type x = Module.x = { ... }] form keeps the test type identical to the
   production type — adding a field in production fails compilation here,
   forcing the test to be updated. *)
type summary = Bar_loader.Summary.t = {
  symbol : string;
  ma_30w : float;
  atr_14 : float;
  rs_line : float;
  stage : Weinstein_types.stage;
  as_of : Date.t;
}
[@@deriving test_matcher]

type metadata = Bar_loader.Metadata.t = {
  symbol : string;
  sector : string;
  last_close : float;
  avg_vol_30d : float option;
  market_cap : float option;
}
[@@deriving test_matcher]

type stats_counts = Bar_loader.stats_counts = {
  metadata : int;
  summary : int;
  full : int;
}
[@@deriving test_matcher]

(** {1 Fixture helpers} *)

let _mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

(** [_daily_series ~start_date ~n ~base ~step] produces [n] consecutive daily
    bars with close = [base +. step * i]. Weekend dates are kept — the bar
    loader and [Time_period.Conversion] treat the series as a plain daily
    stream, so this is fine for tests. *)
let _daily_series ~start_date ~n ~base ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      let close = base +. (step *. Float.of_int i) in
      _mk_bar ~date ~close)

let _ok_or_fail ~context = function
  | Ok v -> v
  | Error (err : Status.t) ->
      assert_failure (Printf.sprintf "%s: %s" context (Status.show err))

let _write_symbol ~data_dir ~symbol ~bars =
  let storage =
    Csv.Csv_storage.create ~data_dir symbol
    |> _ok_or_fail ~context:("Csv_storage.create " ^ symbol)
  in
  Csv.Csv_storage.save storage bars
  |> _ok_or_fail ~context:("Csv_storage.save " ^ symbol)

let _fresh_data_dir () =
  let dir = Filename_unix.temp_dir "bar_loader_summary_test_" "" in
  Fpath.v dir

(** Summary-tier fixture: enough daily bars ending at [as_of] for the loader's
    default 250-day tail + 30-week MA + 52-week RS window to resolve.

    The loader only looks at bars in [as_of - tail_days, as_of]. With
    [tail_days = 250] the tail is ~250 calendar days ≈ ~36 ISO weeks (before
    aggregation); to produce [rs_line] we need [rs_ma_period = 52] WEEKLY bars
    after aggregation, so we configure the loader to fetch a larger tail via
    [summary_config] and generate ~420 days (~60 weeks) of history. *)
let _summary_fixture ?(stock_step = 1.0) ?(benchmark_step = 1.0) () =
  let as_of = Date.create_exn ~y:2023 ~m:Dec ~d:29 in
  let history_days = 420 in
  let start_date = Date.add_days as_of (-history_days) in
  let data_dir = _fresh_data_dir () in
  let stock_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:stock_step
  in
  let benchmark_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:benchmark_step
  in
  _write_symbol ~data_dir ~symbol:"STOCK" ~bars:stock_bars;
  _write_symbol ~data_dir ~symbol:"SPY" ~bars:benchmark_bars;
  let sector_map = String.Table.create () in
  Hashtbl.set sector_map ~key:"STOCK" ~data:"Tech";
  let summary_config =
    { Bar_loader.Summary_compute.default_config with tail_days = history_days }
  in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[ "STOCK" ]
      ~summary_config ()
  in
  (loader, as_of)

(** Short-history fixture: 10 daily bars — not enough for any Summary indicator.
    Used to verify "insufficient history leaves symbol at Metadata". *)
let _short_fixture () =
  let data_dir = _fresh_data_dir () in
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let as_of = Date.create_exn ~y:2023 ~m:Jan ~d:20 in
  let bars = _daily_series ~start_date ~n:10 ~base:100.0 ~step:1.0 in
  _write_symbol ~data_dir ~symbol:"SHORT" ~bars;
  _write_symbol ~data_dir ~symbol:"SPY" ~bars;
  let sector_map = String.Table.create () in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[ "SHORT" ] ()
  in
  (loader, as_of)

(** {1 Tests} *)

let test_promote_to_summary_populates_record _ =
  let loader, as_of = _summary_fixture () in
  let result =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
  in
  assert_that result is_ok;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Summary_tier));
  assert_that
    (Bar_loader.get_summary loader ~symbol:"STOCK")
    (is_some_and
       (* MA: plausibly within the generated price band.
          ATR: with step=1.0 and intraday-flat bars (h=l=c) every close is
          exactly 1.0 above the prior → TR per bar = 1.0 → ATR = 1.0.
          RS: stock and benchmark move identically → normalized RS = 1.0. *)
       (match_summary ~symbol:(equal_to "STOCK") ~as_of:(equal_to as_of)
          ~ma_30w:(is_between (module Float_ord) ~low:100.0 ~high:800.0)
          ~atr_14:(float_equal 1.0) ~rs_line:(float_equal 1.0) ~stage:__))

let test_promote_to_summary_auto_promotes_metadata _ =
  (* Summary promotion should populate the Metadata record too, so callers can
     inspect sector / last_close on a Summary-tier symbol. *)
  let loader, as_of = _summary_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"STOCK")
    (is_some_and
       (match_metadata ~symbol:(equal_to "STOCK") ~sector:(equal_to "Tech")
          ~last_close:__ ~avg_vol_30d:__ ~market_cap:__))

let test_promote_summary_stats_counts _ =
  let loader, as_of = _summary_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 0) ~summary:(equal_to 1)
       ~full:(equal_to 0))

let test_promote_summary_insufficient_history_stays_at_metadata _ =
  (* 10 bars is not enough for ma_30w / rs_line. The symbol should land at
     Metadata tier (no error surfaced). *)
  let loader, as_of = _short_fixture () in
  let result =
    Bar_loader.promote loader ~symbols:[ "SHORT" ] ~to_:Summary_tier ~as_of
  in
  assert_that result is_ok;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"SHORT")
    (is_some_and (equal_to Bar_loader.Metadata_tier));
  assert_that (Bar_loader.get_summary loader ~symbol:"SHORT") is_none;
  (* Metadata is still there. *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"SHORT")
    (is_some_and
       (match_metadata ~symbol:(equal_to "SHORT") ~sector:__ ~last_close:__
          ~avg_vol_30d:__ ~market_cap:__))

let test_promote_summary_is_idempotent _ =
  let loader, as_of = _summary_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote 1"
  in
  let stats_before = Bar_loader.stats loader in
  let summary_before = Bar_loader.get_summary loader ~symbol:"STOCK" in
  (* Second promote to the same tier is a no-op. *)
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote 2"
  in
  assert_that (Bar_loader.stats loader) (equal_to stats_before);
  assert_that
    (Bar_loader.get_summary loader ~symbol:"STOCK")
    (equal_to summary_before)

let test_demote_summary_to_metadata_drops_summary _ =
  let loader, as_of = _summary_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Metadata_tier;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Metadata_tier));
  assert_that (Bar_loader.get_summary loader ~symbol:"STOCK") is_none;
  (* Metadata survives the demotion. *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"STOCK")
    (is_some_and
       (match_metadata ~symbol:(equal_to "STOCK") ~sector:__ ~last_close:__
          ~avg_vol_30d:__ ~market_cap:__));
  (* Stats reflect the move: summary count drops, metadata count rises. *)
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 1) ~summary:(equal_to 0)
       ~full:(equal_to 0))

let test_demote_summary_to_summary_is_noop _ =
  (* Demoting a Summary-tier symbol "to Summary" leaves it exactly where it
     is. This exercises the _tier_rank guard. *)
  let loader, as_of = _summary_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  let summary_before = Bar_loader.get_summary loader ~symbol:"STOCK" in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Summary_tier));
  assert_that
    (Bar_loader.get_summary loader ~symbol:"STOCK")
    (equal_to summary_before)

let test_get_summary_none_for_unknown_symbol _ =
  let loader, _ = _summary_fixture () in
  assert_that (Bar_loader.get_summary loader ~symbol:"NOPE") is_none;
  assert_that (Bar_loader.tier_of loader ~symbol:"NOPE") is_none

let suite =
  "Bar_loader.Summary"
  >::: [
         "promote_to_summary_populates_record"
         >:: test_promote_to_summary_populates_record;
         "promote_to_summary_auto_promotes_metadata"
         >:: test_promote_to_summary_auto_promotes_metadata;
         "promote_summary_stats_counts" >:: test_promote_summary_stats_counts;
         "promote_summary_insufficient_history_stays_at_metadata"
         >:: test_promote_summary_insufficient_history_stays_at_metadata;
         "promote_summary_is_idempotent" >:: test_promote_summary_is_idempotent;
         "demote_summary_to_metadata_drops_summary"
         >:: test_demote_summary_to_metadata_drops_summary;
         "demote_summary_to_summary_is_noop"
         >:: test_demote_summary_to_summary_is_noop;
         "get_summary_none_for_unknown_symbol"
         >:: test_get_summary_none_for_unknown_symbol;
       ]

let () = run_test_tt_main suite
