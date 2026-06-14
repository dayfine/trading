(** Tests for {!Weekly_snapshot_generator.generate}.

    Drives the generator on synthetic bars (a [Breakout] AAPL + [Trending]
    index) so the assertions are deterministic and depend on no cached corpus.
    The breakout pattern is the same shape [test_weinstein_strategy_smoke]'s
    Slice-3 test uses to exercise the screener cascade end-to-end, so a Stage-2
    long candidate is produced. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader
module Generator = Weinstein_snapshot_gen.Weekly_snapshot_generator

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let _index_symbol = "GSPCX"

(* The Friday on which the 40-week-base breakout (from a 2022-01-01 start) is
   inside the screener's breakout-event lookback window, so AAPL screens as a
   Stage-2 long candidate. Confirmed empirically against the synthetic config
   below; later Fridays age the breakout event out of the window. *)
let _as_of = Date.of_string "2022-10-07"
let _system_version = "test-sha-1234"

(* Synthetic config: an AAPL breakout (40-week base then a 3x-volume breakout)
   plus a trending index. Mirrors the smoke test's Slice-3 setup. *)
let _syn_config : Synthetic_source.config =
  {
    start_date = Date.of_string "2022-01-01";
    symbols =
      [
        ( "AAPL",
          Breakout
            {
              base_price = 150.0;
              base_weeks = 40;
              weekly_gain_pct = 0.02;
              breakout_volume_mult = 3.0;
              base_volume = 50_000_000;
            } );
        ( _index_symbol,
          Trending
            {
              start_price = 4500.0;
              weekly_gain_pct = 0.005;
              volume = 1_000_000_000;
            } );
      ];
  }

let _bars_for symbol : Types.Daily_price.t list =
  let ds = Synthetic_source.make _syn_config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol;
      period = Types.Cadence.Daily;
      start_date = Some _syn_config.start_date;
      end_date = None;
    }
  in
  match run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e -> assert_failure ("get_bars failed: " ^ Status.show e)

(* A bar reader over the breakout AAPL + the index. *)
let _breakout_bar_reader () =
  Bar_reader.of_in_memory_bars
    [ ("AAPL", _bars_for "AAPL"); (_index_symbol, _bars_for _index_symbol) ]

let _inputs ~bar_reader ~ticker_sectors : Generator.inputs =
  {
    config =
      Weinstein_strategy.default_config
        ~universe:(List.map ticker_sectors ~f:fst)
        ~index_symbol:_index_symbol;
    system_version = _system_version;
    as_of = _as_of;
    bar_reader;
    ticker_sectors;
    held_positions = [];
  }

let _generate ~bar_reader ~ticker_sectors =
  Generator.generate (_inputs ~bar_reader ~ticker_sectors)

(* The assembled snapshot stamps the requested metadata regardless of data. *)
let test_metadata_stamped _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that snap
    (all_of
       [
         field
           (fun (s : Weekly_snapshot.t) -> s.schema_version)
           (equal_to Weekly_snapshot.current_schema_version);
         field
           (fun (s : Weekly_snapshot.t) -> s.system_version)
           (equal_to _system_version);
         field (fun (s : Weekly_snapshot.t) -> s.date) (equal_to _as_of);
         field (fun (s : Weekly_snapshot.t) -> s.held_positions) (size_is 0);
       ])

(* The breakout AAPL surfaces as a ranked long candidate with a stop below its
   entry (the Weinstein long-stop invariant). *)
let test_breakout_is_long_candidate _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let long_candidates = (snap : Weekly_snapshot.t).long_candidates in
  let aapl =
    List.find long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
        String.equal c.symbol "AAPL")
  in
  assert_that aapl
    (is_some_and
       (all_of
          [
            field
              (fun (c : Weekly_snapshot.candidate) -> c.symbol)
              (equal_to "AAPL");
            field
              (fun (c : Weekly_snapshot.candidate) -> Float.( > ) c.entry 0.0)
              (equal_to true);
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Float.( < ) c.stop c.entry)
              (equal_to true);
            field
              (fun (c : Weekly_snapshot.candidate) -> String.length c.rationale)
              (gt (module Int_ord) 0);
          ]))

(* The macro context is one of the known regime labels and carries a
   confidence in [0, 1]. *)
let test_macro_context_present _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let macro = (snap : Weekly_snapshot.t).macro in
  let regime_known =
    List.mem
      [ "Bullish"; "Bearish"; "Neutral" ]
      macro.regime ~equal:String.equal
  in
  assert_that macro
    (all_of
       [
         field
           (fun (_ : Weekly_snapshot.macro_context) -> regime_known)
           (equal_to true);
         field
           (fun (m : Weekly_snapshot.macro_context) -> m.score)
           (is_between (module Float_ord) ~low:0.0 ~high:1.0);
       ])

(* The snapshot survives a writer -> reader round-trip unchanged. *)
let test_round_trips _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let parsed = Snapshot_reader.parse (Snapshot_writer.serialize snap) in
  assert_that parsed (is_ok_and_holds (equal_to snap))

(* An empty bar reader yields a well-formed snapshot with no candidates — the
   fail-soft "no data" surface (mirrors the strategy's degrade behaviour). *)
let test_empty_universe_no_candidates _ =
  let snap =
    _generate ~bar_reader:(Bar_reader.empty ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that snap
    (all_of
       [
         field (fun (s : Weekly_snapshot.t) -> s.long_candidates) (size_is 0);
         field (fun (s : Weekly_snapshot.t) -> s.short_candidates) (size_is 0);
         field
           (fun (s : Weekly_snapshot.t) -> s.system_version)
           (equal_to _system_version);
       ])

let suite =
  "weekly_snapshot_generator"
  >::: [
         "metadata stamped onto the snapshot" >:: test_metadata_stamped;
         "breakout AAPL is a long candidate" >:: test_breakout_is_long_candidate;
         "macro context is present and well-formed"
         >:: test_macro_context_present;
         "snapshot round-trips through writer/reader" >:: test_round_trips;
         "empty universe yields no candidates"
         >:: test_empty_universe_no_candidates;
       ]

let () = run_test_tt_main suite
