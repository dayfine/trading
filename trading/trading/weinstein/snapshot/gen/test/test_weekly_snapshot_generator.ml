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

(* A Friday soon after the 40-week-base breakout (from a 2022-01-01 start), so
   AAPL is a GENUINELY-EARLY Stage-2 long candidate (weeks_advancing <= 4). The
   generator now chains the stage classifier (see the prior_stage fix in
   [weekly_snapshot_generator._chained_prior_stage] +
   [dev/notes/live-generator-prior-stage-bug-2026-07-01.md]); before that fix it
   passed prior_stage:None, which reset weeks_advancing to ~1 and admitted the
   breakout at ANY later Friday (this date used to be 2022-10-07, ~6 weeks post
   breakout = Stage2 w6, which the corrected <=4-week early-breakout gate rightly
   rejects). Later Fridays now correctly age the candidate out of admission. *)
let _as_of = Date.of_string "2022-09-16"
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

(* A bearish variant: the index declines steadily so the macro gate classifies
   the tape as [Bearish], which must block all long candidates regardless of
   the (still-breaking-out) AAPL. Only the index pattern differs from
   [_syn_config], isolating the macro-gate effect. *)
let _bearish_syn_config : Synthetic_source.config =
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
          Declining
            {
              start_price = 4500.0;
              weekly_loss_pct = 0.03;
              volume = 1_000_000_000;
            } );
      ];
  }

let _bars_for ~syn_config symbol : Types.Daily_price.t list =
  let ds = Synthetic_source.make syn_config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol;
      period = Types.Cadence.Daily;
      start_date = Some syn_config.start_date;
      end_date = None;
    }
  in
  match run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e -> assert_failure ("get_bars failed: " ^ Status.show e)

(* A bar reader over the breakout AAPL + the (trending) index. *)
let _breakout_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ("AAPL", _bars_for ~syn_config:_syn_config "AAPL");
      (_index_symbol, _bars_for ~syn_config:_syn_config _index_symbol);
    ]

(* A bar reader over the breakout AAPL + a declining index. *)
let _bearish_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ("AAPL", _bars_for ~syn_config:_bearish_syn_config "AAPL");
      (_index_symbol, _bars_for ~syn_config:_bearish_syn_config _index_symbol);
    ]

let _inputs_at ~as_of ~bar_reader ~ticker_sectors : Generator.inputs =
  {
    config =
      Weinstein_strategy.default_config
        ~universe:(List.map ticker_sectors ~f:fst)
        ~index_symbol:_index_symbol;
    system_version = _system_version;
    as_of;
    bar_reader;
    ticker_sectors;
    held_positions = [];
  }

(* [_inputs_at] with the resistance-v2 overhead-supply score DISARMED
   ([overhead_supply = None]) — the explicit escape hatch that reverts the
   live display to the v1 binary grade after the 2026-07-23 bundle promotion
   armed it by default. *)
let _disarmed_inputs ~as_of ~bar_reader ~ticker_sectors : Generator.inputs =
  let base = _inputs_at ~as_of ~bar_reader ~ticker_sectors in
  { base with config = { base.config with overhead_supply = None } }

let _inputs ~bar_reader ~ticker_sectors : Generator.inputs =
  _inputs_at ~as_of:_as_of ~bar_reader ~ticker_sectors

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

(* The breakout AAPL surfaces as a ranked long candidate with a populated
   entry / score / rationale (T4: domain outcome, not just "no error"). *)
let test_breakout_is_long_candidate _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let aapl =
    List.find (snap : Weekly_snapshot.t).long_candidates
      ~f:(fun (c : Weekly_snapshot.candidate) -> String.equal c.symbol "AAPL")
  in
  assert_that aapl
    (is_some_and
       (all_of
          [
            field
              (fun (c : Weekly_snapshot.candidate) -> c.symbol)
              (equal_to "AAPL");
            field
              (fun (c : Weekly_snapshot.candidate) -> c.entry)
              (gt (module Float_ord) 0.0);
            field
              (fun (c : Weekly_snapshot.candidate) -> c.score)
              (gt (module Float_ord) 0.0);
            field
              (fun (c : Weekly_snapshot.candidate) -> String.length c.rationale)
              (gt (module Int_ord) 0);
          ]))

(* The long stop sits below the entry (the Weinstein long-stop invariant).
   Asserted on the [entry - stop] projection so the relation is one matcher. *)
let test_breakout_stop_below_entry _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let entry_minus_stop =
    List.find (snap : Weekly_snapshot.t).long_candidates
      ~f:(fun (c : Weekly_snapshot.candidate) -> String.equal c.symbol "AAPL")
    |> Option.map ~f:(fun (c : Weekly_snapshot.candidate) -> c.entry -. c.stop)
  in
  assert_that entry_minus_stop (is_some_and (gt (module Float_ord) 0.0))

(* Regression for the prior_stage-chaining fix. The SAME breakout AAPL, screened
   ~6 weeks later (2022-10-07) is Stage2 w6 under the corrected chained
   classification, so the <=4-week early-breakout gate rightly rejects it — it is
   NOT a long candidate. Before the fix (prior_stage:None reset weeks_advancing
   to ~1) this stale advancer was wrongly surfaced as a fresh pick. See
   [dev/notes/live-generator-prior-stage-bug-2026-07-01.md]. *)
let test_stale_breakout_not_admitted _ =
  let snap =
    Generator.generate
      (_inputs_at
         ~as_of:(Date.of_string "2022-10-07")
         ~bar_reader:(_breakout_bar_reader ())
         ~ticker_sectors:[ ("AAPL", "Information Technology") ])
  in
  let aapl =
    List.find (snap : Weekly_snapshot.t).long_candidates
      ~f:(fun (c : Weekly_snapshot.candidate) -> String.equal c.symbol "AAPL")
  in
  assert_that aapl is_none

(* The macro context carries a known regime label and a confidence in [0, 1].
   The regime is matched against the closed set of known labels via [matching]
   (rather than a boolean predicate), per .claude/rules/test-patterns.md. The
   trending index here screens [Bullish] or [Neutral]; the exact value is
   data-dependent, so this test only pins "a known label". The bearish test
   below pins the exact [Bearish] value. *)
let test_macro_context_present _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that (snap : Weekly_snapshot.t).macro
    (all_of
       [
         field
           (fun (m : Weekly_snapshot.macro_context) -> m.regime)
           (matching ~msg:"regime is one of Bullish / Bearish / Neutral"
              (fun r ->
                if
                  List.mem
                    [ "Bullish"; "Bearish"; "Neutral" ]
                    r ~equal:String.equal
                then Some ()
                else None)
              (equal_to ()));
         field
           (fun (m : Weekly_snapshot.macro_context) -> m.score)
           (is_between (module Float_ord) ~low:0.0 ~high:1.0);
       ])

(* C2 (macro gate): a bearish-macro tape blocks every long candidate, even when
   an individual symbol (AAPL) is still breaking out. The macro regime must read
   [Bearish]. weinstein-book-reference.md §Macro Analysis: a bearish tape blocks
   all buys (the macro gate is unconditional). *)
let test_bearish_macro_blocks_longs _ =
  let snap =
    _generate ~bar_reader:(_bearish_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that snap
    (all_of
       [
         field
           (fun (s : Weekly_snapshot.t) -> s.macro.regime)
           (equal_to "Bearish");
         field (fun (s : Weekly_snapshot.t) -> s.long_candidates) is_empty;
       ])

(* AAPL's [resistance_grade] display string from a generated snapshot. *)
let _aapl_resistance_grade (snap : Weekly_snapshot.t) : string option =
  List.find snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol "AAPL")
  |> Option.bind ~f:(fun (c : Weekly_snapshot.candidate) -> c.resistance_grade)

(* Default (overhead_supply armed by the 2026-07-23 bundle promotion): the
   live generator computes a real sketch from the bar history, so the resistance
   grade renders the v2 sketch-derived form "<quality> (<score>)" — the
   continuous score alongside the letter grade (score/display split, §D5). This
   is the user-visible live-review change the promotion intends. *)
let test_default_resistance_grade_is_v2 _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that
    (_aapl_resistance_grade snap)
    (is_some_and
       (matching ~msg:"v2 grade renders a parenthesized continuous score"
          (fun grade ->
            if String.is_substring grade ~substring:" (" then Some () else None)
          (equal_to ())))

(* Disarmed escape hatch ([overhead_supply = None]): the resistance grade
   degrades to the v1 binary quality label (e.g. "Virgin_territory") — no
   continuous score suffix. The "(" of the v2 "Grade (0.NN)" form is absent, so
   the display is byte-identical to the pre-promotion v1 grade. Pins the
   graceful-degradation fallback (consequence 2b of the bundle promotion). *)
let test_disarmed_resistance_grade_is_v1 _ =
  let snap =
    Generator.generate
      (_disarmed_inputs ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
         ~ticker_sectors:[ ("AAPL", "Information Technology") ])
  in
  assert_that
    (_aapl_resistance_grade snap)
    (is_some_and
       (matching ~msg:"v1 grade carries no continuous score suffix"
          (fun grade ->
            if String.is_substring grade ~substring:"(" then None else Some ())
          (equal_to ())))

(* The displayed grade carries no module-qualified prefix. The derived
   [@@deriving show] printer emits "Weinstein_types.<Constructor>"; the display
   path strips it so the reader sees the bare quality label (P1 #2050
   follow-up). Applies to both v2 and v1 grade strings — both route through
   [_overhead_quality_label]. *)
let test_resistance_grade_has_no_module_prefix _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that
    (_aapl_resistance_grade snap)
    (is_some_and
       (matching ~msg:"grade must not carry a module-qualified prefix"
          (fun grade ->
            if String.is_substring grade ~substring:"Weinstein_types." then None
            else Some ())
          (equal_to ())))

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
         "breakout long stop sits below entry"
         >:: test_breakout_stop_below_entry;
         "stale (w>4) breakout is not admitted"
         >:: test_stale_breakout_not_admitted;
         "macro context is present and well-formed"
         >:: test_macro_context_present;
         "bearish macro blocks all long candidates"
         >:: test_bearish_macro_blocks_longs;
         "default resistance grade shows the v2 score (armed by default)"
         >:: test_default_resistance_grade_is_v2;
         "disarmed resistance grade degrades to the v1 label"
         >:: test_disarmed_resistance_grade_is_v1;
         "resistance grade carries no module-qualified prefix"
         >:: test_resistance_grade_has_no_module_prefix;
         "snapshot round-trips through writer/reader" >:: test_round_trips;
         "empty universe yields no candidates"
         >:: test_empty_universe_no_candidates;
       ]

let () = run_test_tt_main suite
