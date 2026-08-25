(** Unit tests for {!Backtest.Trades_stream} — the incremental [trades.csv]
    appender added for issue #2502.

    Four contracts the module's [.mli] claims, each pinned here:

    - the header is written {b once}, at [create], not once per flush;
    - a process killed mid-run leaves a well-formed CSV holding every round-trip
      closed before the kill (the crash-salvage claim);
    - each round-trip is emitted {b exactly once} across flushes, including when
      a brand-new symbol starts trading between flushes — the case a whole-list
      index would silently corrupt, since
      {!Trading_simulation.Metrics.extract_round_trips} groups by symbol, not by
      time;
    - the completed-run contract is unchanged: {!Trades_stream.write_all} (what
      {!Backtest.Result_writer.write} calls) truncates and rewrites, so the
      finalised file is byte-identical to one a never-streamed run produces. *)

open Core
open OUnit2
open Matchers
module Trades_stream = Backtest.Trades_stream
module Metrics = Trading_simulation.Metrics
module Sim_types = Trading_simulation_types.Simulator_types

let _date = Date.of_string

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _trade ~symbol ~side ~quantity ~price : Trading_base.Types.trade =
  let tag = symbol ^ "-" ^ Float.to_string price in
  {
    id = tag;
    order_id = tag ^ "-order";
    symbol;
    side;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.epoch;
  }

(** One simulator step carrying [trades] on [date]. Only [date] and [trades]
    matter to round-trip extraction; the rest are inert defaults. *)
let _step ~date ~trades : Sim_types.step_result =
  {
    date;
    portfolio = Trading_simulation_types.Portfolio_summary.empty;
    portfolio_value = 100_000.0;
    trades;
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars = true;
  }

(** A buy step then a sell step for [symbol], forming one closed round-trip. *)
let _round_trip_steps ~symbol ~entry ~exit_ ~price =
  [
    _step ~date:entry
      ~trades:
        [ _trade ~symbol ~side:Trading_base.Types.Buy ~quantity:10.0 ~price ];
    _step ~date:exit_
      ~trades:
        [
          _trade ~symbol ~side:Trading_base.Types.Sell ~quantity:10.0
            ~price:(price +. 1.0);
        ];
  ]

(** The snapshot callback the runner supplies in production, reduced to its
    essentials: extract round-trips from every step seen so far. *)
let _snapshot ~steps_rev : Trades_stream.batch =
  {
    round_trips = Metrics.extract_round_trips (List.rev steps_rev);
    stop_infos = [];
    audit = [];
    force_liquidations = [];
  }

let _rm_f path = try Core_unix.remove path with _ -> ()

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "trades_stream_test" "" in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      _rm_f (dir ^ "/trades.csv");
      try Core_unix.rmdir dir with _ -> ())

let _read_lines dir =
  In_channel.read_lines (dir ^ "/trades.csv")
  |> List.filter ~f:(fun l -> not (String.is_empty l))

let _data_rows dir =
  _read_lines dir
  |> List.filter ~f:(fun l -> not (String.equal l Trades_stream.header))

(** Feed [steps] into a fresh stream and return the (still-open) handle. A
    caller that wants the crash shape simply never calls {!Trades_stream.close}.
*)
let _stream_steps ~dir ?every_n_fridays steps =
  let t =
    Trades_stream.create ~output_dir:dir ?every_n_fridays ~snapshot:_snapshot ()
  in
  List.iter steps ~f:(fun (s : Sim_types.step_result) ->
      Trades_stream.record_step t ~date:s.date ~step:s);
  t

(* Consecutive Fridays used by the tests. *)
let _fri1 = _date "2024-01-05"
let _fri2 = _date "2024-01-12"
let _fri3 = _date "2024-01-19"
let _fri4 = _date "2024-01-26"

(** Two round-trips closing on different Fridays, so a cadence of 1 flushes each
    in its own batch. *)
let _two_round_trip_steps ~first ~second =
  _round_trip_steps ~symbol:first ~entry:_fri1 ~exit_:_fri2 ~price:100.0
  @ _round_trip_steps ~symbol:second ~entry:_fri3 ~exit_:_fri4 ~price:200.0

let _n_header_fields = List.length (String.split ~on:',' Trades_stream.header)

(* ------------------------------------------------------------------ *)
(* Tests                                                               *)
(* ------------------------------------------------------------------ *)

(** The header must appear exactly once even though several flushes ran. A
    per-flush header write would produce one matching line per flush. *)
let test_header_written_once _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:1
          (_two_round_trip_steps ~first:"AAPL" ~second:"MSFT")
      in
      Trades_stream.close t;
      assert_that
        (List.count (_read_lines dir) ~f:(String.equal Trades_stream.header))
        (equal_to 1))

(** Crash salvage: the file is present and complete-as-of-the-kill with no
    finalisation at all. Every line carries the header's field count, and both
    closed round-trips are on disk. *)
let test_partial_file_is_well_formed_without_close _ =
  _with_temp_dir (fun dir ->
      (* No [close], no [write_all] — this is the SIGKILL shape. *)
      let _t =
        _stream_steps ~dir ~every_n_fridays:1
          (_two_round_trip_steps ~first:"AAPL" ~second:"MSFT")
      in
      assert_that (_read_lines dir)
        (all_of
           [
             size_is 3;
             each
               (field
                  (fun l -> List.length (String.split ~on:',' l))
                  (equal_to _n_header_fields));
           ]))

(** Every round-trip is emitted exactly once even though a brand-new symbol
    starts trading between flushes.

    [extract_round_trips] folds a symbol-keyed map ascending and prepends each
    symbol's block, so its output runs {b descending} by symbol: ["AAA"] closes
    first and is written first, then ["ZZZ"] appears on the next flush and lands
    {e ahead} of the already-written AAA row. A whole-list [List.drop n] would
    therefore re-emit AAA and never emit ZZZ; only a per-symbol count survives
    the insertion. *)
let test_new_symbol_mid_run_emits_each_round_trip_once _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:1
          (_two_round_trip_steps ~first:"AAA" ~second:"ZZZ")
      in
      Trades_stream.close t;
      let rows = _data_rows dir in
      assert_that
        (List.count rows ~f:(String.is_prefix ~prefix:"AAA,"))
        (equal_to 1);
      assert_that
        (List.count rows ~f:(String.is_prefix ~prefix:"ZZZ,"))
        (equal_to 1);
      assert_that (Trades_stream.rows_written t) (equal_to 2))

(** A re-traded symbol contributes two round-trips in two different flushes.
    Within a symbol the already-emitted prefix must be counted in
    {b entry order}: the extractor emits a symbol's block chronologically, so
    dropping the prefix off a reversed block would re-emit the first round-trip
    and never emit the second. *)
let test_retraded_symbol_emits_both_round_trips _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:1
          (_round_trip_steps ~symbol:"AAPL" ~entry:(_date "2024-01-03")
             ~exit_:_fri1 ~price:100.0
          @ _round_trip_steps ~symbol:"AAPL" ~entry:(_date "2024-01-08")
              ~exit_:_fri2 ~price:200.0)
      in
      Trades_stream.close t;
      let exit_date_cell row = List.nth_exn (String.split ~on:',' row) 3 in
      assert_that
        (List.map (_data_rows dir) ~f:exit_date_cell)
        (unordered_elements_are
           [ equal_to "2024-01-05"; equal_to "2024-01-12" ]))

(** Flush cadence: with [every_n_fridays = 3] the round-trip that closed on the
    second Friday is not on disk yet — only the header is. *)
let test_flush_cadence_defers_write _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:3
          (_round_trip_steps ~symbol:"AAPL" ~entry:_fri1 ~exit_:_fri2
             ~price:100.0)
      in
      Trades_stream.close t;
      assert_that (_data_rows dir) is_empty)

(** Non-Friday steps never trigger a flush: a trade closed on a Wednesday stays
    unwritten until the next Friday boundary. *)
let test_non_friday_steps_do_not_flush _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:1
          (_round_trip_steps ~symbol:"AAPL" ~entry:(_date "2024-01-03")
             ~exit_:(_date "2024-01-10") ~price:100.0)
      in
      Trades_stream.close t;
      assert_that (Trades_stream.rows_written t) (equal_to 0))

(** A non-positive cadence is clamped to 1 rather than raising
    [Division_by_zero] on the [mod] — observability plumbing must never be able
    to kill a multi-hour run. *)
let test_non_positive_cadence_is_clamped _ =
  _with_temp_dir (fun dir ->
      let t =
        _stream_steps ~dir ~every_n_fridays:0
          (_round_trip_steps ~symbol:"AAPL" ~entry:_fri1 ~exit_:_fri2
             ~price:100.0)
      in
      Trades_stream.close t;
      assert_that (Trades_stream.rows_written t) (equal_to 1))

(** The completed-run contract: after a streamed run, the finalising
    {!Trades_stream.write_all} leaves a file byte-identical to the one a
    never-streamed run produces. *)
let test_finalised_file_is_byte_identical_to_unstreamed _ =
  _with_temp_dir (fun streamed_dir ->
      _with_temp_dir (fun plain_dir ->
          let steps = _two_round_trip_steps ~first:"AAPL" ~second:"MSFT" in
          let batch = _snapshot ~steps_rev:(List.rev steps) in
          let t = _stream_steps ~dir:streamed_dir ~every_n_fridays:1 steps in
          Trades_stream.close t;
          Trades_stream.write_all ~output_dir:streamed_dir batch;
          Trades_stream.write_all ~output_dir:plain_dir batch;
          assert_that
            (In_channel.read_all (streamed_dir ^ "/trades.csv"))
            (equal_to (In_channel.read_all (plain_dir ^ "/trades.csv")))))

(** A stream that saw no closed trade still leaves a header-only file, and
    [close] is idempotent. *)
let test_header_only_file_and_idempotent_close _ =
  _with_temp_dir (fun dir ->
      let t = _stream_steps ~dir [] in
      Trades_stream.close t;
      Trades_stream.close t;
      assert_that (_read_lines dir)
        (elements_are [ equal_to Trades_stream.header ]))

let suite =
  "trades_stream"
  >::: [
         "header is written exactly once" >:: test_header_written_once;
         "partial file is well-formed without close"
         >:: test_partial_file_is_well_formed_without_close;
         "each round-trip emitted once when a new symbol appears mid-run"
         >:: test_new_symbol_mid_run_emits_each_round_trip_once;
         "a re-traded symbol emits both round-trips"
         >:: test_retraded_symbol_emits_both_round_trips;
         "flush cadence defers the write" >:: test_flush_cadence_defers_write;
         "non-Friday steps do not flush" >:: test_non_friday_steps_do_not_flush;
         "non-positive cadence is clamped to 1"
         >:: test_non_positive_cadence_is_clamped;
         "finalised file is byte-identical to an unstreamed run"
         >:: test_finalised_file_is_byte_identical_to_unstreamed;
         "header-only file and idempotent close"
         >:: test_header_only_file_and_idempotent_close;
       ]

let () = run_test_tt_main suite
