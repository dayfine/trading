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

(* Sparse-tail eligibility gate fixture helper (issue #2083 fix 1). Drops all
   but every [stride]-th bar within the trailing [window] bars ending at (and
   including) [as_of]'s bar, always keeping the very last (as_of) bar — whose
   close/high are bumped, mirroring the SNSE incident's anomalous spike bar on
   an otherwise-dead feed. The bars BEFORE the window are left fully dense, so
   this simulates a real "long healthy history, sparse recent zombie tail"
   series rather than a globally-thin one. Requires [as_of] to be present in
   [bars] (the synthetic generator emits one bar per weekday). *)
let _sparsify_tail bars ~as_of ~window ~stride : Types.Daily_price.t list =
  match
    List.findi bars ~f:(fun _ (b : Types.Daily_price.t) ->
        Date.equal b.date as_of)
  with
  | None -> bars
  | Some (idx, _) ->
      let window_start = max 0 (idx - window + 1) in
      let before = List.take bars window_start in
      let tail =
        List.sub bars ~pos:window_start ~len:(idx - window_start + 1)
      in
      let last_i = List.length tail - 1 in
      let kept =
        List.filteri tail ~f:(fun i _ -> i mod stride = 0 || i = last_i)
      in
      let spike (b : Types.Daily_price.t) =
        {
          b with
          close_price = b.close_price *. 1.3;
          adjusted_close = b.adjusted_close *. 1.3;
          high_price = b.high_price *. 1.35;
        }
      in
      let n_kept = List.length kept in
      let spiked =
        List.mapi kept ~f:(fun i b -> if i = n_kept - 1 then spike b else b)
      in
      before @ spiked

(* 15-trading-day sparse tail ending at [_as_of], stride 3 -> 6 bars present in
   the window (the "6 bars in ~15 trading days" SNSE shape), dense history
   before it. Only AAPL's tail is sparsified; the index stays fully dense
   (the macro gate is not this gate's concern). *)
let _sparse_tail_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ( "AAPL",
        _sparsify_tail
          (_bars_for ~syn_config:_syn_config "AAPL")
          ~as_of:_as_of ~window:15 ~stride:3 );
      (_index_symbol, _bars_for ~syn_config:_syn_config _index_symbol);
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
    live_portfolio =
      {
        Weinstein_snapshot_gen.Live_portfolio.cash = 100_000.0;
        as_of;
        positions = [];
      };
    portfolio_is_placeholder = true;
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

(* With a live portfolio holding AAPL, the generator prices it into a held row
   (shares + current price + unrealized %) AND excludes it from the candidate
   output (held tickers are not re-recommended). *)
let test_live_portfolio_populates_held _ =
  let position : Weinstein_snapshot_gen.Live_portfolio.position =
    {
      symbol = "AAPL";
      shares = 10;
      entry_price = 150.0;
      entry_date = Date.of_string "2022-01-03";
      stop_price = 140.0;
      stop_state = None;
    }
  in
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let inputs =
    {
      base with
      live_portfolio =
        {
          Weinstein_snapshot_gen.Live_portfolio.cash = 50_000.0;
          as_of = _as_of;
          positions = [ position ];
        };
      portfolio_is_placeholder = false;
    }
  in
  let snap = Generator.generate inputs in
  assert_that snap
    (all_of
       [
         field
           (fun (s : Weekly_snapshot.t) -> s.held_positions)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (h : Weekly_snapshot.held_position) -> h.symbol)
                      (equal_to "AAPL");
                    field
                      (fun (h : Weekly_snapshot.held_position) -> h.shares)
                      (equal_to 10);
                    field
                      (fun (h : Weekly_snapshot.held_position) ->
                        h.current_price)
                      (gt (module Float_ord) 0.0);
                  ];
              ]);
         field
           (fun (s : Weekly_snapshot.t) ->
             List.count s.long_candidates ~f:(fun c ->
                 String.equal c.symbol "AAPL"))
           (equal_to 0);
       ])

(* No-resident-bars graceful degradation for a held position (CP4 pin): a held
   symbol ABSENT from the bar reader must fall back to its entry price (zero
   unrealized) and carry no recomputed stop, per the documented fallbacks in
   [_current_price] / [_unrealized_pct] / [_recommended_stop]. *)
let test_held_without_bars_degrades_gracefully _ =
  let position : Weinstein_snapshot_gen.Live_portfolio.position =
    {
      symbol = "GHOST";
      shares = 7;
      entry_price = 42.0;
      entry_date = Date.of_string "2022-01-03";
      stop_price = 40.0;
      stop_state = None;
    }
  in
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let inputs =
    {
      base with
      live_portfolio =
        {
          Weinstein_snapshot_gen.Live_portfolio.cash = 50_000.0;
          as_of = _as_of;
          positions = [ position ];
        };
      portfolio_is_placeholder = false;
    }
  in
  let snap = Generator.generate inputs in
  assert_that snap
    (field
       (fun (s : Weekly_snapshot.t) -> s.held_positions)
       (elements_are
          [
            all_of
              [
                field
                  (fun (h : Weekly_snapshot.held_position) -> h.symbol)
                  (equal_to "GHOST");
                field
                  (fun (h : Weekly_snapshot.held_position) -> h.current_price)
                  (float_equal 42.0);
                field
                  (fun (h : Weekly_snapshot.held_position) -> h.unrealized_pct)
                  (float_equal 0.0);
                field
                  (fun (h : Weekly_snapshot.held_position) ->
                    h.recommended_stop)
                  is_none;
              ];
          ]))

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

(* Issue #2084 Finding 2: on the default breakout fixture, AAPL's basing noise
   (+/-2%, [_breakout_basing_noise] in [Synthetic_source]) never reaches the
   8% [min_correction_pct] threshold, so no qualifying support floor exists in
   the daily lookback window -> the generator's overlay falls back. But that
   fallback value is NOT the screener's raw fixed-8% proxy
   ([entry * (1 - 0.08)] = [entry * 0.92]) -- it is
   [Weinstein_stops.compute_initial_stop_with_floor]'s OWN fallback formula
   ([entry * initial_stop_buffer], then the state machine's
   [min_correction_pct / 2] haircut and round-number nudge), using the SAME
   config the live strategy's real entry path applies. This pins that the
   generator's overlay actually ran, not a no-op pass-through of
   [Screener.scored_candidate.suggested_stop].

   Mutation check: removing the [_overlay_structural_stop] call from
   [generate] (or replacing it with [Fn.id]) makes [c.stop] equal exactly
   [c.entry *. 0.92] and [is_structural_and_stop_diverges] below goes red. *)
let test_fallback_stop_differs_from_screener_flat_proxy _ =
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
              (fun (c : Weekly_snapshot.candidate) -> c.stop_is_structural)
              (equal_to false);
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Float.abs ((c.stop -. (c.entry *. 0.92)) /. c.entry))
              (gt (module Float_ord) 0.01);
          ]))

(* Issue #2084 Finding 2 (sizing consequence): [sized_risk_amount] must be
   computed from the DISPLAYED (post-overlay) stop, not the screener's
   pre-overlay proxy. If a wiring-order bug applied sizing BEFORE the overlay
   (or overlaid AFTER sizing ran), [sized_risk_amount] would reflect a
   DIFFERENT stop distance than the one [c.stop] displays, and this equality
   would fail.

   Mutation check: swap the [|>] pipe order in [generate] so
   [_size_long] runs before [_overlay_structural_stop] -- [sized_risk_amount]
   is then computed from the screener's pre-overlay [suggested_stop], while
   [c.stop] displays the post-overlay value; the two diverge and this test
   goes red. *)
let test_sizing_uses_overlaid_stop_distance _ =
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
              (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
              (gt (module Int_ord) 0);
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Float.abs
                  (c.sized_risk_amount
                  -. Float.of_int c.sized_shares
                     *. Float.abs (c.entry -. c.stop)))
              (float_equal ~epsilon:0.01 0.0);
          ]))

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

(* ---- Sparse-tail eligibility gate (issue #2083 fix 1) ---- *)

let _sparse_tail_inputs ~sparse_tail_min_bars ~sparse_tail_window_trading_days :
    Generator.inputs =
  let base =
    _inputs_at ~as_of:_as_of
      ~bar_reader:(_sparse_tail_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  {
    base with
    config =
      { base.config with sparse_tail_min_bars; sparse_tail_window_trading_days };
  }

let _is_aapl_long_candidate (snap : Weekly_snapshot.t) =
  List.count snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol "AAPL")

(* R1 (experiment-flag-discipline): [Weinstein_strategy.default_config] itself
   — not just an explicit override — carries the gate disabled. This is the
   config every caller gets unless it opts into
   [dev/weekly-picks/live-config-overrides.sexp] or an equivalent overlay. *)
let test_default_config_has_gate_disabled _ =
  let inputs =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that inputs.config
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.sparse_tail_min_bars)
           (equal_to 0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.sparse_tail_window_trading_days)
           (equal_to 0);
       ])

(* Default (disabled, [sparse_tail_min_bars = 0] / [..window_trading_days = 0])
   is an EXACT no-op (experiment-flag-discipline R1): on a fixture whose tail
   is sparse enough to be dropped if the gate were armed, AAPL still surfaces
   as a long candidate exactly as the un-sparsified breakout fixture does, and
   no warning is emitted. *)
let test_default_disabled_gate_is_bit_identical _ =
  let snap =
    Generator.generate
      (_sparse_tail_inputs ~sparse_tail_min_bars:0
         ~sparse_tail_window_trading_days:0)
  in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 1);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* Armed + sparse tail: with the same fixture, arming the gate at (min_bars=10,
   window=15) — the exact values [dev/weekly-picks/live-config-overrides.sexp]
   uses — drops AAPL from candidate consideration and surfaces a warning
   naming it. This is the direct regression test for issue #2083: without this
   gate AAPL (standing in for SNSE) would have been picked off its sparse,
   spike-laden tail. *)
let test_armed_sparse_tail_drops_candidate_and_warns _ =
  let snap =
    Generator.generate
      (_sparse_tail_inputs ~sparse_tail_min_bars:10
         ~sparse_tail_window_trading_days:15)
  in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 0);
         field
           (fun (s : Weekly_snapshot.t) -> s.warnings)
           (elements_are
              [
                matching ~msg:"warning names AAPL"
                  (fun w ->
                    if String.is_substring w ~substring:"AAPL" then Some ()
                    else None)
                  (equal_to ());
              ]);
       ])

(* Armed + DENSE tail: the same (min_bars=10, window=15) arming, but on the
   unmodified (fully dense) breakout fixture, still retains AAPL as a long
   candidate — proving the gate is not just dropping everything once armed. *)
let test_armed_dense_tail_retains_candidate _ =
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let inputs =
    {
      base with
      config =
        {
          base.config with
          sparse_tail_min_bars = 10;
          sparse_tail_window_trading_days = 15;
        };
    }
  in
  let snap = Generator.generate inputs in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 1);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* ---- Spike-bar data-suspect flag (issue #2083 fix 3) ---- *)

(* The spike fixture is [_sparse_tail_bar_reader]'s series: its LAST bar's close
   is bumped 1.3x (see [_sparsify_tail]'s [spike]) relative to a prior bar three
   trading days earlier, so the last-bar move vs the prior RESIDENT bar is well
   above 30% — the SNSE shape. The sparse-tail gate stays DISABLED here (both
   its fields keep their [0] default), so nothing is dropped and this fixture
   isolates the spike flag: existing
   [test_default_disabled_gate_is_bit_identical] already pins that AAPL is a
   long candidate on it. *)
let _spike_inputs ~spike_bar_threshold_pct : Generator.inputs =
  let base =
    _inputs_at ~as_of:_as_of
      ~bar_reader:(_sparse_tail_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  { base with config = { base.config with spike_bar_threshold_pct } }

(* [(kept?, flagged?)] for AAPL in a generated snapshot: the count of AAPL long
   candidates (1 = kept, 0 = dropped) and whether it carries [data_suspect]. *)
let _aapl_data_suspect (snap : Weekly_snapshot.t) =
  List.find snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol "AAPL")
  |> Option.value_map ~default:false ~f:(fun (c : Weekly_snapshot.candidate) ->
      c.data_suspect)

(* R1 (experiment-flag-discipline): [Weinstein_strategy.default_config] carries
   the spike flag disabled ([spike_bar_threshold_pct = 0.0]) — the config every
   caller gets unless it opts into an overlay. *)
let test_default_config_has_spike_flag_disabled _ =
  let inputs =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that inputs.config
    (field
       (fun (c : Weinstein_strategy.config) -> c.spike_bar_threshold_pct)
       (float_equal 0.0))

(* Default (disabled, [spike_bar_threshold_pct = 0.0]) is an EXACT no-op (R1):
   on a fixture whose last bar IS a 30% spike, AAPL surfaces as an unflagged
   long candidate and no warning is emitted. *)
let test_disabled_spike_flag_is_bit_identical _ =
  let snap = Generator.generate (_spike_inputs ~spike_bar_threshold_pct:0.0) in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 1);
         field _aapl_data_suspect (equal_to false);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* Armed + spiked last bar, pinned at the [generate] SEAM (not at the
   {!Spike_bar_gate.check} primitive): arming the flag at 8% on the spike
   fixture FLAGS AAPL — it is still a ranked long candidate (flag, do not drop:
   count stays 1, unlike the sparse-tail gate) but carries
   [data_suspect = true], and a warning line naming it is surfaced.

   Mutation checks (each turns THIS test red and no other):
   - Deleting the LONG [flag_spikes] call from [_build_candidates] (i.e.
     [let longs, long_warnings = (longs, [])]): [data_suspect] stays [false] and
     [warnings] is empty. (The SHORT call is pinned separately by
     [test_armed_spike_flags_short_candidate_and_warns].)
   - Passing [~threshold_pct:0.0] (the disabled value) instead of
     [inputs.config.spike_bar_threshold_pct] to [Spike_bar_gate.flag_candidates]
     in [_build_candidates]: same two failures.
   - Dropping instead of flagging (filtering out suspects): the count matcher
     goes from 1 to 0. *)
let test_armed_spike_flags_candidate_and_warns _ =
  let snap = Generator.generate (_spike_inputs ~spike_bar_threshold_pct:8.0) in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 1);
         field _aapl_data_suspect (equal_to true);
         field
           (fun (s : Weekly_snapshot.t) -> s.warnings)
           (elements_are
              [
                matching ~msg:"warning names AAPL and says it was kept"
                  (fun w ->
                    if
                      String.is_substring w ~substring:"AAPL"
                      && String.is_substring w ~substring:"kept"
                    then Some ()
                    else None)
                  (equal_to ());
              ]);
       ])

(* Armed + NO spike: the same 8% arming on the unmodified (dense, smoothly
   advancing) breakout fixture leaves AAPL unflagged with no warning — proving
   the flag is not marking every candidate once armed. *)
let test_armed_quiet_series_leaves_candidate_clean _ =
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let snap =
    Generator.generate
      { base with config = { base.config with spike_bar_threshold_pct = 8.0 } }
  in
  assert_that snap
    (all_of
       [
         field _is_aapl_long_candidate (equal_to 1);
         field _aapl_data_suspect (equal_to false);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* A second breakout name with the SAME pattern as AAPL's, whose series is left
   untouched (dense, no spike bar). Pairing it with the spiked AAPL gives the
   flagging pass a TWO-candidate list — the shape needed to pin
   {!Spike_bar_gate.flag_candidates}'s "same length and order ... rank, entry,
   stop and sizing untouched" contract, which a single-candidate list satisfies
   trivially. *)
let _quiet_long_symbol = "MSFT"

let _quiet_long_syn_config : Synthetic_source.config =
  {
    _syn_config with
    symbols =
      [
        ( _quiet_long_symbol,
          Breakout
            {
              base_price = 150.0;
              base_weeks = 40;
              weekly_gain_pct = 0.02;
              breakout_volume_mult = 3.0;
              base_volume = 50_000_000;
            } );
      ];
  }

(* The spike fixture's AAPL (sparsified tail, spiked last bar) plus the quiet
   MSFT and the trending index. *)
let _two_long_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ( "AAPL",
        _sparsify_tail
          (_bars_for ~syn_config:_syn_config "AAPL")
          ~as_of:_as_of ~window:15 ~stride:3 );
      ( _quiet_long_symbol,
        _bars_for ~syn_config:_quiet_long_syn_config _quiet_long_symbol );
      (_index_symbol, _bars_for ~syn_config:_syn_config _index_symbol);
    ]

let _two_long_inputs ~spike_bar_threshold_pct : Generator.inputs =
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_two_long_bar_reader ())
      ~ticker_sectors:
        [
          ("AAPL", "Information Technology");
          (_quiet_long_symbol, "Information Technology");
        ]
  in
  { base with config = { base.config with spike_bar_threshold_pct } }

let _long_symbols (snap : Weekly_snapshot.t) =
  List.map snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      c.symbol)

let _quiet_long_row (snap : Weekly_snapshot.t) =
  List.find snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol _quiet_long_symbol)

(* The quiet row, or a hard test failure — so a fixture regression that stopped
   admitting MSFT surfaces as a failure rather than silently making the
   two-candidate assertions vacuous. *)
let _quiet_long_row_exn snap =
  match _quiet_long_row snap with
  | Some c -> c
  | None -> assert_failure "fixture regression: MSFT is not a long candidate"

(* CP4: the flagging pass is "flag, do not drop" for the WHOLE list, not just
   for the one suspect row. On a two-candidate list where only AAPL spikes,
   arming the flag at 8% leaves the candidate list the same LENGTH and ORDER as
   the disabled run, marks exactly ONE row suspect, and leaves the non-spiking
   MSFT row byte-identical to its disabled-run self (rank position, entry, stop,
   sizing and all). A pass that dropped, reordered or re-decorated rows — or one
   that flagged indiscriminately — fails one of the three matchers. *)
let test_armed_spike_leaves_other_candidates_untouched _ =
  let disabled =
    Generator.generate (_two_long_inputs ~spike_bar_threshold_pct:0.0)
  in
  let armed =
    Generator.generate (_two_long_inputs ~spike_bar_threshold_pct:8.0)
  in
  let quiet_before = _quiet_long_row_exn disabled in
  assert_that armed
    (all_of
       [
         field (fun (s : Weekly_snapshot.t) -> s.long_candidates) (size_is 2);
         field _long_symbols (equal_to (_long_symbols disabled));
         field
           (fun (s : Weekly_snapshot.t) ->
             List.count s.long_candidates
               ~f:(fun (c : Weekly_snapshot.candidate) -> c.data_suspect))
           (equal_to 1);
         field _quiet_long_row (is_some_and (equal_to quiet_before));
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

(* ------------------------------------------------------------------ *)
(* Short-side candidate fixture (generate-seam overlay wiring)          *)
(* ------------------------------------------------------------------ *)

let _short_symbol = "SHRT"

(* SHRT starts LATER than the index (which runs from 2022-01-01) so that at
   [_as_of] only ~33 weekly bars exist: its 30-week MA has just become
   computable and has only just turned down, leaving the stock in EARLY Stage 4
   ([weeks_declining = 3]) — the window
   [Stock_analysis.is_breakdown_candidate] admits as a breakdown setup. Starting
   4 weeks earlier ages it past the <=4-week window and no short candidate is
   produced; starting 4 weeks later leaves no MA at all. *)
let _short_start_date = Date.of_string "2022-02-01"

let _short_syn_config : Synthetic_source.config =
  {
    start_date = _short_start_date;
    symbols =
      [
        ( _short_symbol,
          Declining
            { start_price = 300.0; weekly_loss_pct = 0.04; volume = 20_000_000 }
        );
      ];
  }

(* Counter-rally spliced onto SHRT's final bars: 9 bars at +1.5%/bar is a ~13%
   rally off the trough, comfortably clearing the 8% [min_correction_pct] the
   short-side support-floor primitive requires. *)
let _rally_bars = 9
let _rally_daily_gain = 0.015

(* Volume expansion on the breakdown leg (the 15 bars ending at the trough), so
   the weekly volume ratio reads [Strong] and the short candidate clears the
   default grade-C score floor. Weinstein does not require volume on a
   breakdown, but it is the strongest confirmation when present. *)
let _breakdown_volume_bars = 15
let _breakdown_volume_mult = 3

let _reprice (b : Types.Daily_price.t) price =
  {
    b with
    open_price = price *. 0.995;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
  }

(* SHRT's daily bars: the synthetic decline truncated at [_as_of], with a volume
   spike on the final breakdown leg and its last [_rally_bars] bars re-priced
   into a counter-rally off the trough. The trough (the last bar of the pure
   decline) is then the lowest low of the 90-bar support-floor window, and the
   rally that follows it clears [min_correction_pct] — so
   [Support_floor.find_recent_level ~side:Short] finds a REAL resistance ceiling
   and the overlay reports [stop_is_structural = true]. *)
let _short_bars () =
  let bars =
    _bars_for ~syn_config:_short_syn_config _short_symbol
    |> List.filter ~f:(fun (b : Types.Daily_price.t) -> Date.(b.date <= _as_of))
  in
  let first_rally = List.length bars - _rally_bars in
  let trough =
    List.nth bars (first_rally - 1)
    |> Option.value_map ~default:0.0 ~f:(fun (b : Types.Daily_price.t) ->
        b.close_price)
  in
  List.mapi bars ~f:(fun i b ->
      if i < first_rally - _breakdown_volume_bars then b
      else if i < first_rally then
        { b with volume = b.volume * _breakdown_volume_mult }
      else
        _reprice b
          (trough
          *. ((1.0 +. _rally_daily_gain) ** Float.of_int (i - first_rally + 1))
          ))

(* The counter-rally high: the [as_of] bar's high, which is the maximum high
   after the trough and therefore the resistance ceiling the short-side
   support-floor primitive returns. *)
let _short_rally_high () =
  List.last (_short_bars ())
  |> Option.value_map ~default:0.0 ~f:(fun (b : Types.Daily_price.t) ->
      b.high_price)

(* SHRT plus the declining index, so the macro tape reads [Bearish] — the regime
   that unconditionally admits shorts. *)
let _short_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      (_short_symbol, _short_bars ());
      (_index_symbol, _bars_for ~syn_config:_bearish_syn_config _index_symbol);
    ]

(* Minimal candidate literal for direct {!Stop_recompute.for_candidate} tests.
   [stop] is deliberately seeded LONG-shaped (below entry) so a short-side
   overlay that forgot the side would leave a below-entry stop behind. *)
let _mk_candidate ~symbol ~entry ~stop : Weekly_snapshot.candidate =
  {
    symbol;
    score = 85.0;
    grade = "A";
    entry;
    stop;
    sector = "Test";
    rationale = "test";
    rs_vs_spy = None;
    resistance_grade = None;
    sized_shares = 0;
    sized_position_value = 0.0;
    sized_position_pct = 0.0;
    sized_risk_amount = 0.0;
    sizing_note = None;
    stop_is_structural = false;
    data_suspect = false;
    reconciliation = Entry_reconciliation.Not_reconciled;
  }

let _stops_cfg () =
  let cfg =
    Weinstein_strategy.default_config ~universe:[ "SHRT" ]
      ~index_symbol:_index_symbol
  in
  (cfg.stops_config, cfg.initial_stop_buffer)

(* CP1 / L1-short: the short-side overlay places the recomputed stop ABOVE
   entry — the book's symmetric rule (stop above the prior rally high for
   shorts). The seeded long-shaped stop (below entry) must not survive; a
   side-mixup in the overlay would leave it below. *)
let test_short_candidate_stop_recomputed_above_entry _ =
  let stops_config, initial_stop_buffer = _stops_cfg () in
  let bars = _bars_for ~syn_config:_bearish_syn_config _index_symbol in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("SHRT", bars) ] in
  let entry =
    List.last bars
    |> Option.value_map ~default:100.0 ~f:(fun (b : Types.Daily_price.t) ->
        b.close_price)
  in
  let c =
    Weinstein_snapshot_gen.Stop_recompute.for_candidate ~stops_config
      ~initial_stop_buffer ~bar_reader ~as_of:_as_of
      ~side:Trading_base.Types.Short
      (_mk_candidate ~symbol:"SHRT" ~entry ~stop:(entry *. 0.92))
  in
  assert_that c
    (field
       (fun (c : Weekly_snapshot.candidate) -> c.stop)
       (gt (module Float_ord) entry))

(* Issue #2084 Finding 2, SHORT side, pinned at the [generate] SEAM (not at the
   [Stop_recompute.for_candidate] primitive): a real short candidate produced by
   the screener cascade must carry the structural stop the short-side overlay
   computes, not the screener's flat [entry * (1 + short_stop_pct)] proxy.

   The two assertions are chosen so that BOTH mutations of the overlay call site
   in [weekly_snapshot_generator.generate] turn this test red:

   - Dropping [_overlay_structural_stop] (bare
     [List.map result.short_candidates ~f:Snapshot_display.candidate_of_scored]):
     [stop_is_structural] stays [false] and [stop] becomes [entry * 1.08]
     (~329 here, far outside the asserted band) — the first matcher fails.
   - Passing [~side:Long] instead of [~side:Short]: the long branch still finds
     a qualifying counter-move (so [stop_is_structural] stays [true]), but it
     returns the CORRECTION LOW rather than the rally high, placing the stop
     ~4% BELOW the trough instead of ~4% above the rally high — the band
     matcher fails.

   Weinstein §6.3: a short's initial stop sits above the prior counter-rally
   high. The band is [rally_high, rally_high * 1.10]: the primitive returns the
   rally high, [compute_initial_stop] adds [min_correction_pct / 2] (4%), and
   the round-number nudge moves it at most $0.125 further. *)
let test_short_candidate_overlay_applied_at_generate_seam _ =
  let rally_high = _short_rally_high () in
  let snap =
    _generate ~bar_reader:(_short_bar_reader ())
      ~ticker_sectors:[ (_short_symbol, "Information Technology") ]
  in
  let shrt =
    List.find (snap : Weekly_snapshot.t).short_candidates
      ~f:(fun (c : Weekly_snapshot.candidate) ->
        String.equal c.symbol _short_symbol)
  in
  assert_that shrt
    (is_some_and
       (all_of
          [
            field
              (fun (c : Weekly_snapshot.candidate) -> c.stop_is_structural)
              (equal_to true);
            field
              (fun (c : Weekly_snapshot.candidate) -> c.stop)
              (is_between
                 (module Float_ord)
                 ~low:rally_high ~high:(rally_high *. 1.10));
          ]))

(* ---- Spike-bar flag, SHORT side (issue #2083 fix 3) ---- *)

(* SHRT's series with its LAST bar's close bumped 1.3x (the same [_sparsify_tail]
   spike shape the long fixture uses), so the last-bar move vs the prior bar is
   ~30% — well above the 8% arming below. The bump stays far under the (much
   higher) 30-week MA, so SHRT remains the early-Stage-4 breakdown candidate
   [_short_bars] was built to produce; only the spike flag's input changes. *)
let _short_spike_bars () =
  match List.rev (_short_bars ()) with
  | [] -> []
  | (last : Types.Daily_price.t) :: rest ->
      List.rev
        ({
           last with
           close_price = last.close_price *. 1.3;
           adjusted_close = last.adjusted_close *. 1.3;
           high_price = last.high_price *. 1.35;
         }
        :: rest)

let _short_spike_bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      (_short_symbol, _short_spike_bars ());
      (_index_symbol, _bars_for ~syn_config:_bearish_syn_config _index_symbol);
    ]

let _short_spike_inputs ~spike_bar_threshold_pct : Generator.inputs =
  let base =
    _inputs_at ~as_of:_as_of
      ~bar_reader:(_short_spike_bar_reader ())
      ~ticker_sectors:[ (_short_symbol, "Information Technology") ]
  in
  { base with config = { base.config with spike_bar_threshold_pct } }

(* Number of SHRT rows among the snapshot's short candidates (1 = kept,
   0 = dropped) and the SHRT row itself, for the flag / immutability matchers. *)
let _shrt_short_count (snap : Weekly_snapshot.t) =
  List.count snap.short_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol _short_symbol)

let _shrt_short_row (snap : Weekly_snapshot.t) =
  List.find snap.short_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol _short_symbol)

(* CP1 / CP4, SHORT side, pinned at the [generate] SEAM: the .mli's "Applied to
   long and short candidates alike" claim. Arming the flag at 8% on a SHRT
   series whose last bar spikes ~30% FLAGS the short candidate — it is still a
   ranked short candidate (flag, do not drop: the count stays 1) but carries
   [data_suspect = true], and a warning naming SHRT and stating it was kept is
   surfaced.

   Mutation check (turns THIS test red and no other): replacing
   [let shorts, short_warnings = flag_spikes shorts] with [(shorts, [])] in
   [_build_candidates] — [data_suspect] stays [false] and the warning
   disappears. The long-side seam test cannot see that mutation, which is why
   this test exists. *)
let test_armed_spike_flags_short_candidate_and_warns _ =
  let snap =
    Generator.generate (_short_spike_inputs ~spike_bar_threshold_pct:8.0)
  in
  assert_that snap
    (all_of
       [
         field _shrt_short_count (equal_to 1);
         field _shrt_short_row
           (is_some_and
              (field
                 (fun (c : Weekly_snapshot.candidate) -> c.data_suspect)
                 (equal_to true)));
         field
           (fun (s : Weekly_snapshot.t) -> s.warnings)
           (elements_are
              [
                matching ~msg:"warning names SHRT and says it was kept"
                  (fun w ->
                    if
                      String.is_substring w ~substring:_short_symbol
                      && String.is_substring w ~substring:"kept"
                    then Some ()
                    else None)
                  (equal_to ());
              ]);
       ])

(* CP4: [for_candidate]'s documented "no resident daily bars -> candidate
   returned unchanged" guard — [stop] and [stop_is_structural] untouched. *)
let test_candidate_without_bars_unchanged _ =
  let stops_config, initial_stop_buffer = _stops_cfg () in
  let c =
    Weinstein_snapshot_gen.Stop_recompute.for_candidate ~stops_config
      ~initial_stop_buffer ~bar_reader:(Bar_reader.empty ()) ~as_of:_as_of
      ~side:Trading_base.Types.Long
      (_mk_candidate ~symbol:"GHOST" ~entry:50.0 ~stop:46.0)
  in
  assert_that c
    (all_of
       [
         field
           (fun (c : Weekly_snapshot.candidate) -> c.stop)
           (float_equal 46.0);
         field
           (fun (c : Weekly_snapshot.candidate) -> c.stop_is_structural)
           (equal_to false);
       ])

(* ---- Live rename detection (issue #2083 fix 2) ---- *)

(* Thin the trailing [window] bars to every [stride]-th (the last always kept).
   Unlike [_sparsify_tail] this applies NO spike: a rename fixture needs the
   predecessor's surviving prints to still track the successor's returns
   exactly, which a bumped last bar would destroy. *)
let _thin_tail bars ~as_of ~window ~stride : Types.Daily_price.t list =
  match
    List.findi bars ~f:(fun _ (b : Types.Daily_price.t) ->
        Date.equal b.date as_of)
  with
  | None -> bars
  | Some (idx, _) ->
      let window_start = max 0 (idx - window + 1) in
      let tail =
        List.sub bars ~pos:window_start ~len:(idx - window_start + 1)
      in
      let last_i = List.length tail - 1 in
      List.take bars window_start
      @ List.filteri tail ~f:(fun i _ -> i mod stride = 0 || i = last_i)

(* The successor's leg: the last [window] bars at or before [as_of], on a 1.37x
   adjustment basis. Different LEVELS, identical RETURNS — the signature the
   detector scores. The [as_of] truncation matters: the synthetic source emits
   bars well past the as-of date, so taking the tail of the raw list would place
   the whole leg in the future. *)
let _successor_leg bars ~as_of ~window : Types.Daily_price.t list =
  let upto =
    List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
        Date.( <= ) b.date as_of)
  in
  List.drop upto (max 0 (List.length upto - window))
  |> List.map ~f:(fun (b : Types.Daily_price.t) ->
      { b with adjusted_close = b.adjusted_close *. 1.37 })

let _rename_window = 15

(* AAPL (dense, unrelated control) + ZOMB (AAPL's series with a 22-day zombie
   tail) + ZOMBN (ZOMB's successor) + the index. ZOMB -> ZOMBN is the only
   succession present: AAPL and the index are dense, so neither can be a
   predecessor, and ZOMB/AAPL start on the same day, so neither can succeed the
   other. *)
let _rename_bar_reader () =
  let aapl = _bars_for ~syn_config:_syn_config "AAPL" in
  Bar_reader.of_in_memory_bars
    [
      ("AAPL", aapl);
      ("ZOMB", _thin_tail aapl ~as_of:_as_of ~window:_rename_window ~stride:3);
      ("ZOMBN", _successor_leg aapl ~as_of:_as_of ~window:_rename_window);
      (_index_symbol, _bars_for ~syn_config:_syn_config _index_symbol);
    ]

let _rename_inputs ~rename_detect_min_overlap_days ~rename_detect_match_fraction
    : Generator.inputs =
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_rename_bar_reader ())
      ~ticker_sectors:
        [
          ("AAPL", "Information Technology");
          ("ZOMB", "Information Technology");
          ("ZOMBN", "Information Technology");
        ]
  in
  {
    base with
    config =
      {
        base.config with
        rename_detect_min_overlap_days;
        rename_detect_match_fraction;
      };
  }

let _long_symbols (snap : Weekly_snapshot.t) =
  List.map snap.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      c.symbol)

(* R1 (experiment-flag-discipline): [Weinstein_strategy.default_config] carries
   rename detection disabled — the config every caller gets unless it opts into
   an overlay. Both knobs must sit at their no-op value. *)
let test_default_config_has_rename_detect_disabled _ =
  let inputs =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that inputs.config
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) ->
             c.rename_detect_min_overlap_days)
           (equal_to 0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.rename_detect_match_fraction)
           (float_equal 0.0);
       ])

(* Disabled (the default) is an EXACT no-op on a fixture that WOULD be caught if
   armed: the superseded ZOMB still surfaces as a long candidate beside AAPL,
   and no warning is emitted. *)
let test_disabled_rename_detect_is_bit_identical _ =
  let snap =
    Generator.generate
      (_rename_inputs ~rename_detect_min_overlap_days:0
         ~rename_detect_match_fraction:0.0)
  in
  assert_that snap
    (all_of
       [
         field _long_symbols (elements_are [ equal_to "AAPL"; equal_to "ZOMB" ]);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* Armed: the SAME fixture now drops the superseded ZOMB, KEEPS the unrelated
   AAPL, and emits one warning naming both the dead ticker and its successor.
   Both halves are pinned — asserting the exact candidate list fails if the
   wrong symbol is dropped or if nothing is. This is the direct regression test
   for issue #2083 Finding 2. *)
let test_armed_rename_detect_drops_predecessor_and_warns _ =
  let snap =
    Generator.generate
      (_rename_inputs ~rename_detect_min_overlap_days:5
         ~rename_detect_match_fraction:0.95)
  in
  assert_that snap
    (all_of
       [
         field _long_symbols (elements_are [ equal_to "AAPL" ]);
         field
           (fun (s : Weekly_snapshot.t) -> s.warnings)
           (elements_are
              [
                matching ~msg:"warning naming ZOMB and its successor ZOMBN"
                  (fun w ->
                    if
                      String.is_substring w ~substring:"ZOMB"
                      && String.is_substring w ~substring:"ZOMBN"
                    then Some ()
                    else None)
                  (equal_to ());
              ]);
       ])

(* ORDER: rename detection must run BEFORE the sparse-tail gate. The zombie tail
   that identifies a superseded ticker is exactly what the sparse-tail gate
   removes, so running second would erase the evidence.

   With both armed on the rename fixture, ZOMB is sparse enough for either stage
   to drop it, but only one of them names the successor. Rename-first ->
   exactly one warning, naming ZOMBN. Sparse-first -> a sparse-tail warning that
   never mentions ZOMBN, because by then ZOMB is no longer in the list to be
   matched against it. *)
let test_rename_detect_runs_before_the_sparse_tail_gate _ =
  let base =
    _rename_inputs ~rename_detect_min_overlap_days:5
      ~rename_detect_match_fraction:0.95
  in
  let snap =
    Generator.generate
      {
        base with
        config =
          {
            base.config with
            sparse_tail_min_bars = 10;
            sparse_tail_window_trading_days = 15;
          };
      }
  in
  assert_that snap.warnings
    (elements_are
       [
         matching ~msg:"the surviving warning is the rename one (names ZOMBN)"
           (fun w ->
             if String.is_substring w ~substring:"ZOMBN" then Some () else None)
           (equal_to ());
       ])

(* Armed on a universe with nothing renamed leaves the run untouched — the
   detector is not simply dropping whatever it is pointed at once enabled. *)
let test_armed_rename_detect_on_clean_universe_is_a_no_op _ =
  let base =
    _inputs_at ~as_of:_as_of ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  let snap =
    Generator.generate
      {
        base with
        config =
          {
            base.config with
            rename_detect_min_overlap_days = 5;
            rename_detect_match_fraction = 0.95;
          };
      }
  in
  assert_that snap
    (all_of
       [
         field _long_symbols (elements_are [ equal_to "AAPL" ]);
         field (fun (s : Weekly_snapshot.t) -> s.warnings) is_empty;
       ])

(* ------------------------------------------------------------------ *)
(* Entry reconciliation at the generate seam (issue #2103)              *)
(* ------------------------------------------------------------------ *)

let _armed_inputs ~bar_reader ~ticker_sectors ~through_band_pct
    ~extension_max_pct : Generator.inputs =
  let base = _inputs ~bar_reader ~ticker_sectors in
  {
    base with
    config =
      {
        base.config with
        entry_through_band_pct = through_band_pct;
        entry_extension_max_pct = extension_max_pct;
      };
  }

(* The close the reconciliation must pick up, read through the SAME reader the
   generator uses (so this is data, not a re-implementation). *)
let _reader_close bar_reader symbol =
  Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:_as_of
  |> List.last
  |> Option.value_map ~default:0.0 ~f:(fun (b : Types.Daily_price.t) ->
      b.close_price)

let _find_candidate candidates symbol =
  List.find candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      String.equal c.symbol symbol)

let _class_label (c : Weekly_snapshot.candidate) =
  Entry_reconciliation.label c.reconciliation

let _overshoot (c : Weekly_snapshot.candidate) =
  Option.map (Entry_reconciliation.levels_of c.reconciliation)
    ~f:(fun (l : Entry_reconciliation.levels) -> l.overshoot_pct)

(* Thresholds wide enough to force [Through_entry] whichever side of its entry
   the synthetic fixture's close happens to sit on: a band below any achievable
   overshoot and a cap above one. The exact close of a [Synthetic_source]
   breakout is a property of that generator, not of this feature, so forcing the
   class keeps the assertion about the WIRING rather than about the fixture. *)
let _wide_band = -1000.0
let _wide_cap = 1000.0

(* LONG arm at the generate seam. Two independent claims:

   1. the pass ran at all — the candidate carries a real class, where a
      no-op wiring would leave [Not_reconciled] and no levels;
   2. {b sizing is anchored to the reconciled fill}, which is the actual #2103
      defect: [sized_position_value] equals [sized_shares * close]. Under the
      pre-fix code it equalled [sized_shares * entry], and the guard matcher
      below asserts those two are genuinely different for this fixture, so the
      test cannot pass by coincidence. *)
let test_long_candidate_reconciled_and_sized_on_the_fill _ =
  let bar_reader = _breakout_bar_reader () in
  let close = _reader_close bar_reader "AAPL" in
  let snap =
    Generator.generate
      (_armed_inputs ~bar_reader
         ~ticker_sectors:[ ("AAPL", "Information Technology") ]
         ~through_band_pct:_wide_band ~extension_max_pct:_wide_cap)
  in
  assert_that
    (_find_candidate (snap : Weekly_snapshot.t).long_candidates "AAPL")
    (is_some_and
       (all_of
          [
            field _class_label (is_some_and (equal_to "through-entry"));
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Weekly_snapshot.expected_fill_price c)
              (float_equal close);
            field
              (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
              (gt (module Int_ord) 0);
            field
              (fun (c : Weekly_snapshot.candidate) ->
                c.sized_position_value -. (Float.of_int c.sized_shares *. close))
              (float_equal 0.0);
            (* Guard: entry and close differ, so "sized on the fill" and "sized
               on the entry" are distinguishable outcomes here. *)
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Float.abs (c.entry -. close))
              (gt (module Float_ord) 0.01);
          ]))

(* R1 no-op: with the default config (both thresholds [0.0]) the same fixture
   produces an UNRECONCILED candidate sized on its entry level — bit-identical
   to pre-#2103 behaviour. *)
let test_default_config_leaves_candidates_unreconciled _ =
  let snap =
    _generate ~bar_reader:(_breakout_bar_reader ())
      ~ticker_sectors:[ ("AAPL", "Information Technology") ]
  in
  assert_that
    (_find_candidate (snap : Weekly_snapshot.t).long_candidates "AAPL")
    (is_some_and
       (all_of
          [
            field
              (fun (c : Weekly_snapshot.candidate) -> c.reconciliation)
              (equal_to Entry_reconciliation.Not_reconciled);
            field _class_label is_none;
            field
              (fun (c : Weekly_snapshot.candidate) ->
                c.sized_position_value
                -. (Float.of_int c.sized_shares *. c.entry))
              (float_equal 0.0);
          ]))

(* SHORT arm at the generate seam — the mirror.

   Mutation checks, both of which this single test catches:

   - dropping [_reconcile_entry] from the short pipeline in
     [weekly_snapshot_generator._build_candidates] leaves [Not_reconciled], so
     the class matcher and the overshoot matcher both fail;
   - passing [~side:`Long] instead of [~side:`Short] flips the SIGN of the
     overshoot (the long form is [(close - entry) / entry], the short form its
     mirror), so the overshoot matcher fails. The guard matcher pins that entry
     and close differ here, which is what makes the two signs distinguishable. *)
let test_short_candidate_reconciled_at_generate_seam _ =
  let bar_reader = _short_bar_reader () in
  let close = _reader_close bar_reader _short_symbol in
  let snap =
    Generator.generate
      (_armed_inputs ~bar_reader
         ~ticker_sectors:[ (_short_symbol, "Information Technology") ]
         ~through_band_pct:_wide_band ~extension_max_pct:_wide_cap)
  in
  assert_that
    (_find_candidate (snap : Weekly_snapshot.t).short_candidates _short_symbol)
    (is_some_and
       (all_of
          [
            field _class_label (is_some_and (equal_to "through-entry"));
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Option.value (_overshoot c) ~default:0.0
                -. ((c.entry -. close) /. c.entry *. 100.0))
              (float_equal 0.0);
            field
              (fun (c : Weekly_snapshot.candidate) ->
                Float.abs (c.entry -. close))
              (gt (module Float_ord) 0.01);
          ]))

let suite =
  "weekly_snapshot_generator"
  >::: [
         "long candidate reconciled and sized on the fill"
         >:: test_long_candidate_reconciled_and_sized_on_the_fill;
         "default config leaves candidates unreconciled"
         >:: test_default_config_leaves_candidates_unreconciled;
         "short candidate reconciled at the generate seam"
         >:: test_short_candidate_reconciled_at_generate_seam;
         "short candidate stop recomputed above entry"
         >:: test_short_candidate_stop_recomputed_above_entry;
         "short candidate overlay applied at the generate seam"
         >:: test_short_candidate_overlay_applied_at_generate_seam;
         "candidate without bars returned unchanged"
         >:: test_candidate_without_bars_unchanged;
         "metadata stamped onto the snapshot" >:: test_metadata_stamped;
         "live portfolio populates held positions"
         >:: test_live_portfolio_populates_held;
         "held symbol without bars degrades gracefully"
         >:: test_held_without_bars_degrades_gracefully;
         "breakout AAPL is a long candidate" >:: test_breakout_is_long_candidate;
         "breakout long stop sits below entry"
         >:: test_breakout_stop_below_entry;
         "fallback stop differs from the screener's flat 8% proxy"
         >:: test_fallback_stop_differs_from_screener_flat_proxy;
         "sizing uses the overlaid (post-structural-stop) distance"
         >:: test_sizing_uses_overlaid_stop_distance;
         "stale (w>4) breakout is not admitted"
         >:: test_stale_breakout_not_admitted;
         "macro context is present and well-formed"
         >:: test_macro_context_present;
         "bearish macro blocks all long candidates"
         >:: test_bearish_macro_blocks_longs;
         "default_config has the sparse-tail gate disabled"
         >:: test_default_config_has_gate_disabled;
         "default (disabled) sparse-tail gate is bit-identical"
         >:: test_default_disabled_gate_is_bit_identical;
         "armed sparse tail drops candidate and warns"
         >:: test_armed_sparse_tail_drops_candidate_and_warns;
         "armed dense tail retains candidate"
         >:: test_armed_dense_tail_retains_candidate;
         "default_config has rename detection disabled"
         >:: test_default_config_has_rename_detect_disabled;
         "default (disabled) rename detection is bit-identical"
         >:: test_disabled_rename_detect_is_bit_identical;
         "armed rename detection drops the predecessor and warns"
         >:: test_armed_rename_detect_drops_predecessor_and_warns;
         "rename detection runs before the sparse-tail gate"
         >:: test_rename_detect_runs_before_the_sparse_tail_gate;
         "armed rename detection on a clean universe is a no-op"
         >:: test_armed_rename_detect_on_clean_universe_is_a_no_op;
         "default_config has the spike-bar flag disabled"
         >:: test_default_config_has_spike_flag_disabled;
         "default (disabled) spike flag is bit-identical"
         >:: test_disabled_spike_flag_is_bit_identical;
         "armed spike flags candidate (kept) and warns"
         >:: test_armed_spike_flags_candidate_and_warns;
         "armed quiet series leaves candidate clean"
         >:: test_armed_quiet_series_leaves_candidate_clean;
         "armed spike leaves the other candidate untouched \
          (length/order/fields)"
         >:: test_armed_spike_leaves_other_candidates_untouched;
         "armed spike flags SHORT candidate (kept) and warns"
         >:: test_armed_spike_flags_short_candidate_and_warns;
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
