(** Tests for [Backtest.Tiered_runner.promote_universe_metadata]'s tolerance of
    per-symbol CSV-missing failures.

    Pins the parity property that the nightly Legacy-vs-Tiered A/B compare does
    {e not} verify: the A/B fixtures are always complete, so a regression where
    Tiered raises [Failure] on a single missing CSV while Legacy silently skips
    the symbol would slip through the A/B. Legacy's simulator tolerates missing
    CSVs via its own bar cache; Tiered must match, otherwise a real data dir
    (with the usual handful of delisted / renamed symbols whose CSVs dropped
    out) diverges.

    [Bar_loader.promote]'s contract (see the [val promote] docstring in
    [bar_loader.mli]) returns the first per-symbol error, so a naive
    [match Ok () | Error _ -> failwith] would be wrong — exactly the bug this
    test guards against. *)

open OUnit2
open Core
open Matchers
module Bar_loader = Bar_loader

(* -------------------------------------------------------------------- *)
(* Fixtures                                                             *)
(* -------------------------------------------------------------------- *)

let _as_of = Date.create_exn ~y:2024 ~m:Jan ~d:31

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

(** A handful of daily bars ending well before [_as_of] so Metadata-tier's
    last-bar-on-or-before-[as_of] lookup finds one. *)
let _make_bars =
  [
    _mk_bar ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:3) ~close:100.0;
    _mk_bar ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:4) ~close:101.0;
    _mk_bar ~date:(Date.create_exn ~y:2024 ~m:Jan ~d:5) ~close:102.0;
  ]

let _ok_or_fail ~context = function
  | Ok v -> v
  | Error (err : Status.t) ->
      assert_failure (Printf.sprintf "%s: %s" context (Status.show err))

let _write_symbol ~data_dir ~symbol =
  let storage =
    Csv.Csv_storage.create ~data_dir symbol
    |> _ok_or_fail ~context:("Csv_storage.create " ^ symbol)
  in
  Csv.Csv_storage.save storage _make_bars
  |> _ok_or_fail ~context:("Csv_storage.save " ^ symbol)

(** Build a [Tiered_runner.input] sufficient for [promote_universe_metadata].
    The other [input] fields ([ad_bars], [config]) are not read by the
    Metadata-promote path, so we fill them with [default_config] values and
    empty [ad_bars]. *)
let _make_input ~data_dir ~all_symbols : Backtest.Tiered_runner.input =
  {
    data_dir_fpath = data_dir;
    ticker_sectors = Hashtbl.create (module String);
    ad_bars = [];
    config =
      Weinstein_strategy.default_config ~universe:all_symbols
        ~index_symbol:"SPY";
    all_symbols;
  }

let _make_loader ~data_dir ~all_symbols =
  let sector_map = Hashtbl.create (module String) in
  Bar_loader.create ~data_dir ~sector_map ~universe:all_symbols ()

(* -------------------------------------------------------------------- *)
(* Tests                                                                *)
(* -------------------------------------------------------------------- *)

(** Three-symbol universe where only [HAVE] has a CSV on disk; [MISSING1] and
    [MISSING2] are absent. [promote_universe_metadata] must not raise, and the
    three-symbol tier state must be: [HAVE] at Metadata, the others untracked.

    This is the regression test for the comment in [tiered_runner.ml] that used
    to read "a hard load error indicates a broken data directory" — false per
    [Bar_loader.promote]'s contract: a single missing CSV produces [Error]
    without the data directory being broken. *)
let test_partial_missing_does_not_raise _ =
  let tmp_dir = Filename_unix.temp_dir "tiered_metadata_tolerance_" "" in
  let data_dir = Fpath.v tmp_dir in
  _write_symbol ~data_dir ~symbol:"HAVE";
  let all_symbols = [ "HAVE"; "MISSING1"; "MISSING2" ] in
  let loader = _make_loader ~data_dir ~all_symbols in
  let input = _make_input ~data_dir ~all_symbols in
  (* Must not raise. *)
  Backtest.Tiered_runner.promote_universe_metadata loader input ~as_of:_as_of;
  assert_that
    (Bar_loader.tier_of loader ~symbol:"HAVE")
    (is_some_and (equal_to Bar_loader.Metadata_tier));
  assert_that (Bar_loader.tier_of loader ~symbol:"MISSING1") is_none;
  assert_that (Bar_loader.tier_of loader ~symbol:"MISSING2") is_none;
  assert_that
    (Bar_loader.get_metadata loader ~symbol:"HAVE")
    (is_some_and
       (field (fun (m : Bar_loader.Metadata.t) -> m.symbol) (equal_to "HAVE")));
  assert_that (Bar_loader.get_metadata loader ~symbol:"MISSING1") is_none;
  assert_that (Bar_loader.get_metadata loader ~symbol:"MISSING2") is_none

(** Degenerate case: every symbol fails. [promote_universe_metadata] still must
    not raise — this is the "symmetry with Legacy" guarantee (Legacy would
    simply produce an empty backtest). *)
let test_all_missing_does_not_raise _ =
  let tmp_dir = Filename_unix.temp_dir "tiered_metadata_tolerance_" "" in
  let data_dir = Fpath.v tmp_dir in
  let all_symbols = [ "MISSING1"; "MISSING2"; "MISSING3" ] in
  let loader = _make_loader ~data_dir ~all_symbols in
  let input = _make_input ~data_dir ~all_symbols in
  Backtest.Tiered_runner.promote_universe_metadata loader input ~as_of:_as_of;
  let stats = Bar_loader.stats loader in
  assert_that stats.metadata (equal_to 0);
  assert_that stats.summary (equal_to 0);
  assert_that stats.full (equal_to 0)

(** Sanity: when every symbol has a CSV, the function still works end-to-end and
    tier state is correct. Guards against a regression where the per-symbol fold
    drops successful promotes. *)
let test_all_present_promotes_all _ =
  let tmp_dir = Filename_unix.temp_dir "tiered_metadata_tolerance_" "" in
  let data_dir = Fpath.v tmp_dir in
  _write_symbol ~data_dir ~symbol:"AAA";
  _write_symbol ~data_dir ~symbol:"BBB";
  _write_symbol ~data_dir ~symbol:"CCC";
  let all_symbols = [ "AAA"; "BBB"; "CCC" ] in
  let loader = _make_loader ~data_dir ~all_symbols in
  let input = _make_input ~data_dir ~all_symbols in
  Backtest.Tiered_runner.promote_universe_metadata loader input ~as_of:_as_of;
  let stats = Bar_loader.stats loader in
  assert_that stats.metadata (equal_to 3);
  assert_that stats.summary (equal_to 0);
  assert_that stats.full (equal_to 0)

let suite =
  "Runner_tiered_metadata_tolerance"
  >::: [
         "partial missing CSVs: does not raise, successful symbol reaches \
          Metadata, missing symbols untracked"
         >:: test_partial_missing_does_not_raise;
         "all missing CSVs: does not raise, loader empty"
         >:: test_all_missing_does_not_raise;
         "all present: promotes all symbols to Metadata"
         >:: test_all_present_promotes_all;
       ]

let () = run_test_tt_main suite
