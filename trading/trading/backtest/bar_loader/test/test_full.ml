(** Integration tests for Bar_loader — 3c (Full tier).

    These tests exercise Full-tier promotion / demotion end-to-end against CSV
    fixtures. The Summary scalar math is covered by [test_summary_compute.ml]
    and [test_summary.ml]; here we focus on the Full-specific plumbing:

    - promote Metadata → Full cascades through Summary
    - [get_full] returns the raw bar tail
    - demote Full → Summary keeps Summary scalars, drops the bars
    - demote Full → Metadata drops both higher tiers *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* Re-declare records here with [@@deriving test_matcher] so ppx_test_matcher
   generates exhaustive [match_<name>] helpers. The [type x = Module.x = {...}]
   form keeps the test type identical to the production type — adding a field
   in production fails compilation here, forcing the test to be updated. *)
type full = Bar_loader.Full.t = {
  symbol : string;
  bars : Types.Daily_price.t list;
  as_of : Date.t;
}
[@@deriving test_matcher]

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
  let dir = Filename_unix.temp_dir "bar_loader_full_test_" "" in
  Fpath.v dir

(** Full-tier fixture: ~420 days of synthetic history so both Summary and Full
    promotions have enough bars to resolve. Summary tail defaults to 250 days;
    we override both tail configs to 420 so the entire synthetic history is
    retained on Full promotion, making [List.length bars] testable against the
    generated count. *)
let _full_fixture () =
  let as_of = Date.create_exn ~y:2023 ~m:Dec ~d:29 in
  let history_days = 420 in
  let start_date = Date.add_days as_of (-history_days) in
  let data_dir = _fresh_data_dir () in
  let stock_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:1.0
  in
  let benchmark_bars =
    _daily_series ~start_date ~n:history_days ~base:100.0 ~step:1.0
  in
  _write_symbol ~data_dir ~symbol:"STOCK" ~bars:stock_bars;
  _write_symbol ~data_dir ~symbol:"SPY" ~bars:benchmark_bars;
  let sector_map = String.Table.create () in
  Hashtbl.set sector_map ~key:"STOCK" ~data:"Tech";
  let summary_config =
    { Bar_loader.Summary_compute.default_config with tail_days = history_days }
  in
  let full_config : Bar_loader.Full_compute.config =
    { tail_days = history_days }
  in
  let loader =
    Bar_loader.create ~data_dir ~sector_map ~universe:[ "STOCK" ]
      ~summary_config ~full_config ()
  in
  (loader, as_of, history_days)

(** {1 Tests} *)

let test_promote_to_full_populates_record _ =
  let loader, as_of, history_days = _full_fixture () in
  let result =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
  in
  assert_that result is_ok;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Full_tier));
  assert_that
    (Bar_loader.get_full loader ~symbol:"STOCK")
    (is_some_and
       (* [as_of]: matches the date of the last CSV bar ≤ the promote
          [as_of]. Since we generated bars up to the day before [as_of],
          [Full.as_of] sits at [as_of - 1] — pin ≤ rather than strict-equal.
          [bars]: exact count depends on [Csv_storage.get]'s inclusive
          boundary semantics; pin only that most bars landed. *)
       (match_full ~symbol:(equal_to "STOCK")
          ~as_of:(field (fun d -> Date.(d <= as_of)) (equal_to true))
          ~bars:
            (field
               (fun bs -> List.length bs)
               (gt (module Int_ord) (history_days / 2)))))

let test_promote_to_full_auto_promotes_summary _ =
  (* Full promotion should cascade through Summary, so [get_summary] returns
     the scalars (and Metadata is joined too, via the Summary cascade). *)
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  assert_that
    (Bar_loader.get_summary loader ~symbol:"STOCK")
    (is_some_and
       (match_summary ~symbol:(equal_to "STOCK") ~ma_30w:__ ~atr_14:__
          ~rs_line:__ ~stage:__ ~as_of:__));
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"STOCK")
    (is_some_and
       (match_metadata ~symbol:__ ~sector:(equal_to "Tech") ~last_close:__
          ~avg_vol_30d:__ ~market_cap:__))

let test_promote_full_stats_counts _ =
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 0) ~summary:(equal_to 0)
       ~full:(equal_to 1))

let test_promote_full_is_idempotent _ =
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote 1"
  in
  let full_before = Bar_loader.get_full loader ~symbol:"STOCK" in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote 2"
  in
  assert_that
    (Bar_loader.get_full loader ~symbol:"STOCK")
    (equal_to full_before)

let test_demote_full_to_summary_keeps_summary_drops_bars _ =
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  let summary_before = Bar_loader.get_summary loader ~symbol:"STOCK" in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Summary_tier));
  assert_that (Bar_loader.get_full loader ~symbol:"STOCK") is_none;
  (* Summary scalars survive the demotion — that's the point of the
     keep-Summary path (cheap re-promote to Full if needed). *)
  assert_that
    (Bar_loader.get_summary loader ~symbol:"STOCK")
    (equal_to summary_before);
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 0) ~summary:(equal_to 1)
       ~full:(equal_to 0))

let test_demote_full_to_metadata_drops_both _ =
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Metadata_tier;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Metadata_tier));
  assert_that (Bar_loader.get_full loader ~symbol:"STOCK") is_none;
  assert_that (Bar_loader.get_summary loader ~symbol:"STOCK") is_none;
  (* Metadata survives — per plan §Resolutions #6, Full → Metadata is a full
     drop of higher-tier data; Metadata stays put. *)
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"STOCK")
    (is_some_and
       (match_metadata ~symbol:(equal_to "STOCK") ~sector:__ ~last_close:__
          ~avg_vol_30d:__ ~market_cap:__));
  assert_that (Bar_loader.stats loader)
    (match_stats_counts ~metadata:(equal_to 1) ~summary:(equal_to 0)
       ~full:(equal_to 0))

let test_demote_full_to_full_is_noop _ =
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Full_tier ~as_of
    |> _ok_or_fail ~context:"promote Full"
  in
  let full_before = Bar_loader.get_full loader ~symbol:"STOCK" in
  Bar_loader.demote loader ~symbols:[ "STOCK" ] ~to_:Full_tier;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"STOCK")
    (is_some_and (equal_to Bar_loader.Full_tier));
  assert_that
    (Bar_loader.get_full loader ~symbol:"STOCK")
    (equal_to full_before)

let test_get_full_none_for_lower_tier_symbol _ =
  (* A symbol promoted only to Summary should return [None] from [get_full]. *)
  let loader, as_of, _ = _full_fixture () in
  let _ =
    Bar_loader.promote loader ~symbols:[ "STOCK" ] ~to_:Summary_tier ~as_of
    |> _ok_or_fail ~context:"promote Summary"
  in
  assert_that (Bar_loader.get_full loader ~symbol:"STOCK") is_none;
  assert_that (Bar_loader.get_full loader ~symbol:"NOPE") is_none

let suite =
  "Bar_loader.Full"
  >::: [
         "promote_to_full_populates_record"
         >:: test_promote_to_full_populates_record;
         "promote_to_full_auto_promotes_summary"
         >:: test_promote_to_full_auto_promotes_summary;
         "promote_full_stats_counts" >:: test_promote_full_stats_counts;
         "promote_full_is_idempotent" >:: test_promote_full_is_idempotent;
         "demote_full_to_summary_keeps_summary_drops_bars"
         >:: test_demote_full_to_summary_keeps_summary_drops_bars;
         "demote_full_to_metadata_drops_both"
         >:: test_demote_full_to_metadata_drops_both;
         "demote_full_to_full_is_noop" >:: test_demote_full_to_full_is_noop;
         "get_full_none_for_lower_tier_symbol"
         >:: test_get_full_none_for_lower_tier_symbol;
       ]

let () = run_test_tt_main suite
