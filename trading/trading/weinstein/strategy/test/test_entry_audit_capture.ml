(** Pin the G14-fix-B contract for [Entry_audit_capture]: when the screener's
    [cand.suggested_entry] differs from the most recent close in [bar_reader] at
    [current_date], the produced [Position.CreateEntering] and [entry_event] use
    the realised entry (current close), while the audit row's [candidate] field
    still carries the screener's pre-fill intent verbatim.

    See [dev/notes/g14-deep-dive-2026-05-01.md] for the bug + fix shape. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _ticker = "ZZZZ"

(** Build a one-symbol [Bar_reader.t] whose most recent (and only) bar has
    [close_price = current_close]. The bar reader's [daily_bars_for] returns a
    list with this bar; [_effective_entry_price] reads its [close_price] as the
    realised entry. *)
let _bar_reader_with_current_close ~current_date ~current_close : Bar_reader.t =
  let bar : Types.Daily_price.t =
    {
      date = current_date;
      open_price = current_close;
      high_price = current_close *. 1.01;
      low_price = current_close *. 0.99;
      close_price = current_close;
      adjusted_close = current_close;
      volume = 1_000_000;
      active_through = None;
    }
  in
  Bar_reader.of_in_memory_bars [ (_ticker, [ bar ]) ]

(** Construct a minimal [Stage.result] for the analysis bundle. The fields are
    required by [scored_candidate] but [make_entry_transition] doesn't read them
    — only [suggested_entry] / [suggested_stop] / [side] flow through. *)
let _stage_result : Stage.result =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
    ma_value = 100.0;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.01;
    transition = None;
    above_ma_count = 8;
  }

let _stock_analysis ~ticker ~as_of_date : Stock_analysis.t =
  {
    ticker;
    stage = _stage_result;
    rs = None;
    volume = None;
    resistance = None;
    support = None;
    breakout_price = None;
    breakdown_price = None;
    prior_stage = None;
    continuation = None;
    supply = None;
    as_of_date;
  }

let _sector_context : Screener.sector_context =
  {
    sector_name = "Test";
    rating = Neutral;
    stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
  }

(** Build a long [scored_candidate] whose [suggested_entry] is divorced from
    [bar_reader]'s current close. This is the configuration that exposes the G14
    bug pre-fix. *)
let _long_candidate ~ticker ~suggested_entry ~suggested_stop ~as_of_date :
    Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker ~as_of_date;
    sector = _sector_context;
    side = Trading_base.Types.Long;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry;
    suggested_stop;
    risk_pct = (suggested_entry -. suggested_stop) /. suggested_entry;
    swing_target = None;
    rationale = [ "test breakout"; "test volume confirm" ];
  }

(** Short counterpart to {!_long_candidate}. The Stage4 fixture is interchanged
    with Stage2 in the analysis bundle to satisfy the screener's directional
    invariant; [make_entry_transition] does not read it but
    [_short_notional_cap_*] tests still construct it for symmetry. *)
let _short_candidate ~ticker ~suggested_entry ~suggested_stop ~as_of_date :
    Screener.scored_candidate =
  {
    ticker;
    analysis = _stock_analysis ~ticker ~as_of_date;
    sector = _sector_context;
    side = Trading_base.Types.Short;
    grade = Weinstein_types.B;
    score = 60;
    suggested_entry;
    suggested_stop;
    risk_pct = (suggested_stop -. suggested_entry) /. suggested_entry;
    swing_target = None;
    rationale = [ "test breakdown" ];
  }

let _portfolio_risk_config : Portfolio_risk.config =
  Portfolio_risk.default_config

let _stops_config : Weinstein_stops.config = Weinstein_stops.default_config

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** With [suggested_entry = $130] and bar_reader returning current close $110,
    [make_entry_transition] must produce a [CreateEntering] whose
    [entry_price = $110] — the realised price the broker will fill at — and
    sizing keys off this realised price too. *)
let test_effective_entry_overrides_suggested_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:110.0
  in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Entry_ok"
       (function
         | Entry_audit_capture.Entry_ok (trans, meta) -> Some (trans, meta)
         | _ -> None)
       (all_of
          [
            field
              (fun ((trans : Position.transition), _) ->
                match trans.kind with
                | Position.CreateEntering e -> e.entry_price
                | _ -> Float.nan)
              (float_equal 110.0);
            field
              (fun (_, (m : Entry_audit_capture.entry_meta)) ->
                m.effective_entry_price)
              (float_equal 110.0);
          ]))

(** [build_entry_event] must compute [initial_position_value] and
    [initial_risk_dollars] off [meta.effective_entry_price] (realised entry),
    not the screener's pre-fill [candidate.suggested_entry]. The candidate field
    on the audit row keeps [suggested_entry] verbatim so audit consumers can
    reconcile screener intent vs realised entry. *)
let test_entry_event_audit_dollars_use_effective_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:110.0
  in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let trans_and_meta =
    match
      Entry_audit_capture.make_entry_transition
        ~portfolio_risk_config:_portfolio_risk_config
        ~stops_config:_stops_config ~initial_stop_buffer:0.92 ~stop_states
        ~bar_reader ~portfolio_value:100_000.0 ~current_date cand
    with
    | Entry_audit_capture.Entry_ok (trans, meta) -> (trans, meta)
    | _ -> OUnit2.assert_failure "make_entry_transition did not return Entry_ok"
  in
  let _, meta = trans_and_meta in
  let macro : Macro.result =
    {
      index_stage = _stage_result;
      indicators = [];
      trend = Weinstein_types.Bullish;
      confidence = 0.80;
      regime_changed = false;
      rationale = [ "fixture" ];
    }
  in
  let event =
    Entry_audit_capture.build_entry_event ~macro ~current_date ~candidate:cand
      ~meta ~alternatives:[]
  in
  let expected_position_value =
    Float.of_int meta.shares *. meta.effective_entry_price
  in
  let expected_risk_dollars =
    Float.of_int meta.shares
    *. Float.abs (meta.effective_entry_price -. meta.installed_stop)
  in
  assert_that event
    (all_of
       [
         (* Realised-entry-anchored dollar fields. *)
         field
           (fun e -> e.Audit_recorder.initial_position_value)
           (float_equal expected_position_value);
         field
           (fun e -> e.Audit_recorder.initial_risk_dollars)
           (float_equal expected_risk_dollars);
         (* Candidate is passed through verbatim — screener intent preserved. *)
         field
           (fun e -> e.Audit_recorder.candidate.Screener.suggested_entry)
           (float_equal 130.0);
         (* Position-state shares + stop come from [meta]. *)
         field (fun e -> e.Audit_recorder.shares) (equal_to meta.shares);
         field
           (fun e -> e.Audit_recorder.installed_stop)
           (float_equal meta.installed_stop);
       ])

(** When [bar_reader] has no bars for the candidate's ticker (e.g., a test
    fixture that didn't pre-populate a panel for it), [_effective_entry_price]
    falls back to [cand.suggested_entry]. The fallback path must keep the
    pre-G14 behaviour bit-equivalent so tests / synthetic fixtures that don't
    seed bars still drive deterministic entry construction. *)
let test_empty_bar_reader_falls_back_to_suggested_entry _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader = Bar_reader.empty () in
  let cand =
    (* suggested_stop = $100 sits below current_close $110 — required so the
       Long stop-on-correct-side check passes. The screener's pre-fill stop
       computed off suggested_entry $130 would be in the same neighbourhood
       (~$120, but here we simply pick a value that satisfies the directional
       invariant after Fix B remaps entry to $110). *)
    _long_candidate ~ticker:_ticker ~suggested_entry:130.0 ~suggested_stop:100.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Entry_ok"
       (function
         | Entry_audit_capture.Entry_ok (trans, meta) -> Some (trans, meta)
         | _ -> None)
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) ->
            m.effective_entry_price)
          (float_equal 130.0)))

(* ------------------------------------------------------------------ *)
(* G15 step 2: short-notional cap tests                                  *)
(* ------------------------------------------------------------------ *)

(** Build a stub [(Position.transition, entry_meta)] pair carrying an effective
    entry + share count, suitable for driving
    {!Entry_audit_capture.check_short_notional_cap}. We bypass
    [make_entry_transition] here because the cap math is independent of the
    sizing path — it keys solely off [meta.shares * meta.effective_entry_price]
    — and constructing a fixture that produces the exact share count we want via
    [compute_position_size] would couple the test to risk-config defaults. *)
let _stub_trans_and_meta ~side ~shares ~effective_entry_price :
    Position.transition * Entry_audit_capture.entry_meta =
  let trans : Position.transition =
    {
      position_id = "STUB-1";
      date = Date.of_string "2024-06-14";
      kind =
        Position.CreateEntering
          {
            symbol = "STUB";
            side;
            target_quantity = Float.of_int shares;
            entry_price = effective_entry_price;
            reasoning = Position.ManualDecision { description = "stub" };
          };
    }
  in
  let meta : Entry_audit_capture.entry_meta =
    {
      position_id = "STUB-1";
      shares;
      installed_stop = effective_entry_price *. 0.95;
      stop_floor_kind = Audit_recorder.Buffer_fallback;
      effective_entry_price;
    }
  in
  (trans, meta)

(** Portfolio at $100K with 25% existing short notional ($25K). A fresh short
    candidate sized to $6K notional → 31% > 30% cap → must skip with
    [Short_notional_cap]. *)
let test_short_notional_cap_skips_at_31pct _ =
  let short_notional_acc = ref 25_000.0 in
  let short_notional_cap = 100_000.0 *. 0.30 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Short ~shares:60
      ~effective_entry_price:100.0
  in
  let cand =
    _short_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:115.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_short_notional_cap ~short_notional_acc
      ~short_notional_cap (trans, meta) cand
  in
  assert_that result is_none;
  (* Accumulator unchanged when the cap rejects. *)
  assert_that !short_notional_acc (float_equal 25_000.0)

(** 25% existing + $4K candidate → 29% < 30% cap → admitted, accumulator
    advances to 29%. *)
let test_short_notional_cap_admits_at_29pct _ =
  let short_notional_acc = ref 25_000.0 in
  let short_notional_cap = 100_000.0 *. 0.30 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Short ~shares:40
      ~effective_entry_price:100.0
  in
  let cand =
    _short_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:115.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_short_notional_cap ~short_notional_acc
      ~short_notional_cap (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 40)));
  assert_that !short_notional_acc (float_equal 29_000.0)

(** Long candidate is a no-op: 25% existing short notional + a long candidate
    must always pass through the cap regardless of the candidate's notional. *)
let test_short_notional_cap_does_not_block_longs _ =
  let short_notional_acc = ref 25_000.0 in
  let short_notional_cap = 100_000.0 *. 0.30 in
  (* A long with $50K notional — well over the cap if it counted. *)
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:500
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_short_notional_cap ~short_notional_acc
      ~short_notional_cap (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 500)));
  (* Long admission must not bump the short accumulator. *)
  assert_that !short_notional_acc (float_equal 25_000.0)

(** Empty portfolio (zero existing short notional) + 5% short candidate (well
    under the 30% cap) → admitted; accumulator records the 5%. *)
let test_short_notional_cap_zero_existing _ =
  let short_notional_acc = ref 0.0 in
  let short_notional_cap = 100_000.0 *. 0.30 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Short ~shares:50
      ~effective_entry_price:100.0
  in
  let cand =
    _short_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:115.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_short_notional_cap ~short_notional_acc
      ~short_notional_cap (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 50)));
  assert_that !short_notional_acc (float_equal 5_000.0)

(* ------------------------------------------------------------------ *)
(* G15 step 3: stop-too-wide rejection at entry + sizing-uses-installed-stop *)
(* ------------------------------------------------------------------ *)

(** Long candidate with current_close=$100 and initial_stop_buffer=0.80 → the
    fallback support-floor stop sits at $80, i.e. 20% below entry. With the
    default [max_stop_distance_pct = 0.15], the gate must fire and the result
    must be [Stop_too_wide]. No [stop_states] entry should be written; no
    position id should be consumed. *)
let test_long_stop_too_wide_rejects_at_20pct _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    _long_candidate ~ticker:_ticker ~suggested_entry:100.0 ~suggested_stop:95.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let initial_stop_states_size = Map.length !stop_states in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.80 (* 20% below entry → over the 15% gate *)
      ~stop_states ~bar_reader ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Stop_too_wide"
       (function Entry_audit_capture.Stop_too_wide -> Some () | _ -> None)
       (equal_to ()));
  (* Pin the no-side-effect contract: stop_states untouched. *)
  assert_that (Map.length !stop_states) (equal_to initial_stop_states_size)

(** Short counterpart: with current_close=$100 and initial_stop_buffer=0.80, the
    short-side fallback ref is $100/0.80=$125 (25% above entry → also over the
    15% gate). *)
let test_short_stop_too_wide_rejects_at_25pct _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    _short_candidate ~ticker:_ticker ~suggested_entry:100.0
      ~suggested_stop:108.0 ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.80 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Stop_too_wide"
       (function Entry_audit_capture.Stop_too_wide -> Some () | _ -> None)
       (equal_to ()))

(** Long with initial_stop_buffer=0.92 → fallback stop at 8% below entry, well
    under 15% → must produce [Entry_ok]. Pins the admit-side of the gate. *)
let test_stop_within_15pct_admits _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    _long_candidate ~ticker:_ticker ~suggested_entry:100.0 ~suggested_stop:95.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 (* 8% below entry → under the 15% gate *)
      ~stop_states ~bar_reader ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Entry_ok"
       (function
         | Entry_audit_capture.Entry_ok (_, meta) -> Some meta | _ -> None)
       (* Sanity: meta.installed_stop sits comfortably under 15% from $100
          entry. The actual value is ~$88.32 (= support_floor level ~$92 ×
          0.96 buffer-on-floor); range is 85..95 to accommodate the
          buffer-on-floor compounding without pinning the exact value. *)
       (field
          (fun (m : Entry_audit_capture.entry_meta) -> m.installed_stop)
          (is_between (module Float_ord) ~low:85.0 ~high:95.0)))

(** Vol-scaled stop / [max_stop_distance_pct] interaction (reject side). The
    vol-scaled-stop dial feeds its widened floor in via [min_stop_distance_pct]
    (see {!Entry_stop_distance.min_stop_distance_for}); the 15% reject cap must
    apply {e after} that floor. Here a 20% min-distance floor (what a high-ATR
    name would produce) is passed directly while the natural buffer stays tight
    (8%), so it is the floor — not the buffer — that crosses the cap. The result
    must be [Stop_too_wide] with no [stop_states] side-effect. Pins the
    documented contract in [stop_types.mli] §[vol_scaled_stop_atr_mult]. *)
let test_vol_scaled_floor_over_cap_rejects _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    _long_candidate ~ticker:_ticker ~suggested_entry:100.0 ~suggested_stop:95.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let initial_stop_states_size = Map.length !stop_states in
  let result =
    Entry_audit_capture.make_entry_transition ~min_stop_distance_pct:0.20
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92
        (* natural 8% buffer — under the cap on its own *)
      ~stop_states ~bar_reader ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Stop_too_wide"
       (function Entry_audit_capture.Stop_too_wide -> Some () | _ -> None)
       (equal_to ()));
  assert_that (Map.length !stop_states) (equal_to initial_stop_states_size)

(** Vol-scaled stop / cap interaction (admit side). A 12% min-distance floor
    sits under the 15% cap, so the widened stop is admitted ([Entry_ok]) and the
    installed stop lands at the floor (~12% below the $100 entry). Confirms the
    floor only rejects when it actually exceeds the cap. *)
let test_vol_scaled_floor_under_cap_admits _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    _long_candidate ~ticker:_ticker ~suggested_entry:100.0 ~suggested_stop:95.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let result =
    Entry_audit_capture.make_entry_transition ~min_stop_distance_pct:0.12
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 ~stop_states ~bar_reader
      ~portfolio_value:100_000.0 ~current_date cand
  in
  assert_that result
    (matching ~msg:"Expected Entry_ok"
       (function
         | Entry_audit_capture.Entry_ok (_, meta) -> Some meta | _ -> None)
       (field
          (fun (m : Entry_audit_capture.entry_meta) -> m.installed_stop)
          (is_between (module Float_ord) ~low:86.0 ~high:89.0)))

(** Pin sizing-uses-installed-stop: configure [cand.suggested_stop] divorced
    from [installed_stop] (suggested at 5% below entry, installed at 8% below
    entry) and confirm the [risk_amount] embedded in [meta] keys off
    [installed_stop], not [cand.suggested_stop]. The test reads
    [shares * |effective_entry - installed_stop|] and compares to
    [portfolio_value * risk_per_trade_pct] (the fixed-risk-sizing contract). *)
let test_sizing_uses_installed_stop _ =
  let current_date = Date.of_string "2024-06-14" in
  let bar_reader =
    _bar_reader_with_current_close ~current_date ~current_close:100.0
  in
  let cand =
    (* suggested_stop $95 — pre-step-3 sizing would have keyed off this. *)
    _long_candidate ~ticker:_ticker ~suggested_entry:100.0 ~suggested_stop:95.0
      ~as_of_date:current_date
  in
  let stop_states = ref String.Map.empty in
  let portfolio_value = 100_000.0 in
  let result =
    Entry_audit_capture.make_entry_transition
      ~portfolio_risk_config:_portfolio_risk_config ~stops_config:_stops_config
      ~initial_stop_buffer:0.92 (* installed_stop ~$92, distance ~8% *)
      ~stop_states ~bar_reader ~portfolio_value ~current_date cand
  in
  let meta =
    match result with
    | Entry_audit_capture.Entry_ok (_, m) -> m
    | _ -> OUnit2.assert_failure "expected Entry_ok"
  in
  let risk_per_share =
    Float.abs (meta.effective_entry_price -. meta.installed_stop)
  in
  let risk_dollars = Float.of_int meta.shares *. risk_per_share in
  let risk_per_trade_pct = _portfolio_risk_config.risk_per_trade_pct in
  let target_risk_dollars = portfolio_value *. risk_per_trade_pct in
  (* Risk-per-share should match installed_stop, not suggested_stop:
     - installed_stop-based: |100 - 92| = 8 → shares = 1000*0.01/8 = 1.25 → 1
     - suggested_stop-based: |100 - 95| = 5 → shares = 1000*0.01/5 = 2.0 → 2
     The realised risk_dollars must be at-or-below target_risk_dollars (the
     floor() rounding produces a strict inequality, but we never overshoot). *)
  assert_that risk_dollars (le (module Float_ord) target_risk_dollars);
  (* Pin the actual installed_stop landed near the buffered floor (~$88.32 =
     support_floor ~$92 × 0.96), not the screener's suggested $95. This
     catches a regression where sizing re-keyed off cand.suggested_stop. *)
  assert_that meta.installed_stop
    (is_between (module Float_ord) ~low:85.0 ~high:94.0)

(* ------------------------------------------------------------------ *)
(* P1 2026-05-15: per-sector exposure cap gate                          *)
(* ------------------------------------------------------------------ *)

(** Default-off path: when [max_sector_exposure_pct = None], the gate is a no-op
    pass-through regardless of accumulator state or sector. *)
let test_sector_exposure_cap_off_passes_through _ =
  let sector_exposure_acc = Hashtbl.create (module String) in
  Hashtbl.set sector_exposure_acc ~key:"Test" ~data:99_000.0;
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:100
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_sector_exposure_cap ~sector_exposure_acc
      ~max_sector_exposure_pct:None ~portfolio_value:100_000.0 (trans, meta)
      cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 100)))

(** Cap=0.30 + Test sector at 28% ($28K of $100K) + a candidate adding $5K
    notional → projected 33% > 30% → rejection. Accumulator must NOT advance on
    rejection. *)
let test_sector_exposure_cap_rejects_at_33pct _ =
  let sector_exposure_acc = Hashtbl.create (module String) in
  Hashtbl.set sector_exposure_acc ~key:"Test" ~data:28_000.0;
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:50
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_sector_exposure_cap ~sector_exposure_acc
      ~max_sector_exposure_pct:(Some 0.30) ~portfolio_value:100_000.0
      (trans, meta) cand
  in
  assert_that result is_none;
  assert_that
    (Hashtbl.find_exn sector_exposure_acc "Test")
    (float_equal 28_000.0)

(** Cap=0.30 + Test sector at 20% + a candidate adding $5K → projected 25% →
    admitted, accumulator advances to $25K. *)
let test_sector_exposure_cap_admits_at_25pct _ =
  let sector_exposure_acc = Hashtbl.create (module String) in
  Hashtbl.set sector_exposure_acc ~key:"Test" ~data:20_000.0;
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:50
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_sector_exposure_cap ~sector_exposure_acc
      ~max_sector_exposure_pct:(Some 0.30) ~portfolio_value:100_000.0
      (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 50)));
  assert_that
    (Hashtbl.find_exn sector_exposure_acc "Test")
    (float_equal 25_000.0)

(** Empty-string sector is exempt — even with cap=0.05 and a $50K candidate, an
    unknown-sector candidate passes the exposure check. The accumulator is NOT
    bumped (the bucket is exempt from tracking too). *)
let test_sector_exposure_cap_exempts_empty_sector _ =
  let sector_exposure_acc = Hashtbl.create (module String) in
  let unknown_sector : Screener.sector_context =
    { sector_name = ""; rating = Neutral; stage = _sector_context.stage }
  in
  let cand =
    {
      (_long_candidate ~ticker:"STUB" ~suggested_entry:100.0
         ~suggested_stop:90.0
         ~as_of_date:(Date.of_string "2024-06-14"))
      with
      sector = unknown_sector;
    }
  in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:500
      ~effective_entry_price:100.0
  in
  let result =
    Entry_audit_capture.check_sector_exposure_cap ~sector_exposure_acc
      ~max_sector_exposure_pct:(Some 0.05) ~portfolio_value:100_000.0
      (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 500)));
  (* No bump on the empty bucket — the cap exempts it from both checking
     and tracking. *)
  assert_that (Hashtbl.find sector_exposure_acc "") is_none

(** Successive admissions accumulate: two $10K candidates to the same sector
    against a 0.30 cap and a $0 starting accumulator. First admits to $10K;
    second admits to $20K. *)
let test_sector_exposure_cap_accumulates_across_candidates _ =
  let sector_exposure_acc = Hashtbl.create (module String) in
  let candidate () =
    let trans, meta =
      _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:100
        ~effective_entry_price:100.0
    in
    let cand =
      _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
        ~as_of_date:(Date.of_string "2024-06-14")
    in
    Entry_audit_capture.check_sector_exposure_cap ~sector_exposure_acc
      ~max_sector_exposure_pct:(Some 0.30) ~portfolio_value:100_000.0
      (trans, meta) cand
  in
  let r1 = candidate () in
  let r2 = candidate () in
  assert_that r1
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 100)));
  assert_that r2
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 100)));
  assert_that
    (Hashtbl.find_exn sector_exposure_acc "Test")
    (float_equal 20_000.0)

(* ------------------------------------------------------------------ *)
(* P0b 2026-07-13: long-exposure cap gate                               *)
(* ------------------------------------------------------------------ *)

(** Default no-op: [long_notional_cap = Float.infinity] (config field [<= 0.0])
    admits any long regardless of accumulator state — a $60K long against a $0
    accumulator passes. The accumulator still advances so cross-candidate
    bookkeeping stays consistent. *)
let test_long_notional_cap_off_passes_through _ =
  let long_notional_acc = ref 0.0 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:600
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_long_notional_cap ~long_notional_acc
      ~long_notional_cap:Float.infinity (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 600)));
  assert_that !long_notional_acc (float_equal 60_000.0)

(** Portfolio at $100K with 66% existing long notional ($66K) and a 70% cap. A
    fresh $6K long → 72% > 70% → must skip; accumulator unchanged on rejection.
*)
let test_long_notional_cap_skips_at_72pct _ =
  let long_notional_acc = ref 66_000.0 in
  let long_notional_cap = 100_000.0 *. 0.70 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:60
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_long_notional_cap ~long_notional_acc
      ~long_notional_cap (trans, meta) cand
  in
  assert_that result is_none;
  assert_that !long_notional_acc (float_equal 66_000.0)

(** 66% existing + $4K long → 70% = cap → admitted (cap is inclusive);
    accumulator advances to $70K. *)
let test_long_notional_cap_admits_at_cap _ =
  let long_notional_acc = ref 66_000.0 in
  let long_notional_cap = 100_000.0 *. 0.70 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:40
      ~effective_entry_price:100.0
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_long_notional_cap ~long_notional_acc
      ~long_notional_cap (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 40)));
  assert_that !long_notional_acc (float_equal 70_000.0)

(** Short candidate is a no-op for the long cap: even with a $0 cap and a $50K
    short, the long-cap gate passes it through and does not bump the long
    accumulator. *)
let test_long_notional_cap_does_not_block_shorts _ =
  let long_notional_acc = ref 25_000.0 in
  let trans, meta =
    _stub_trans_and_meta ~side:Trading_base.Types.Short ~shares:500
      ~effective_entry_price:100.0
  in
  let cand =
    _short_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:115.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let result =
    Entry_audit_capture.check_long_notional_cap ~long_notional_acc
      ~long_notional_cap:0.0 (trans, meta) cand
  in
  assert_that result
    (is_some_and
       (field
          (fun (_, (m : Entry_audit_capture.entry_meta)) -> m.shares)
          (equal_to 500)));
  assert_that !long_notional_acc (float_equal 25_000.0)

(** End-to-end through [classify_candidate]: a long whose $60K entry notional
    breaches the $50K cap is tagged [Skipped Long_exposure_cap], and the cash
    tentatively deducted by the cash gate is refunded (the exit-safety
    contract). *)
let test_long_exposure_cap_classify_skips_and_refunds _ =
  let remaining_cash = ref 100_000.0 in
  let long_notional_acc = ref 0.0 in
  let make_entry _ =
    let trans, meta =
      _stub_trans_and_meta ~side:Trading_base.Types.Long ~shares:600
        ~effective_entry_price:100.0
    in
    Entry_audit_capture.Entry_ok (trans, meta)
  in
  let cand =
    _long_candidate ~ticker:"STUB" ~suggested_entry:100.0 ~suggested_stop:90.0
      ~as_of_date:(Date.of_string "2024-06-14")
  in
  let decision =
    Entry_audit_capture.classify_candidate ~held_set:String.Set.empty
      ~make_entry ~remaining_cash ~short_notional_acc:(ref 0.0)
      ~short_notional_cap:Float.infinity ~long_notional_acc
      ~long_notional_cap:(100_000.0 *. 0.50)
      ~sector_exposure_acc:(Hashtbl.create (module String))
      ~max_sector_exposure_pct:None ~portfolio_value:100_000.0 cand
  in
  assert_that decision
    (matching ~msg:"expected Skipped Long_exposure_cap"
       (function Entry_audit_capture.Skipped r -> Some r | _ -> None)
       (equal_to
          (Audit_recorder.Long_exposure_cap : Audit_recorder.skip_reason)));
  assert_that !remaining_cash (float_equal 100_000.0)

(** Build a [Holding] {!Position.t} for [ticker] at [entry] with [qty] shares on
    [side]. Mirrors the helper in [test_harvest_rotate_runner.ml]; used to seed
    the long-notional accumulator. *)
let _make_holding ?(side = Trading_base.Types.Long) ~ticker ~qty ~entry () :
    Position.t =
  let date = Date.of_string "2024-06-14" in
  let make_trans kind = { Position.position_id = ticker; date; kind } in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side;
              target_quantity = qty;
              entry_price = entry;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = qty; fill_price = entry }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(** [initial_long_notional] seeds only from [Holding] LONGS at entry price: a
    100-share $50 long contributes $5K; a co-held short contributes nothing. *)
let test_initial_long_notional_seeds_from_long_holdings _ =
  let positions =
    String.Map.of_alist_exn
      [
        ("LONGA", _make_holding ~ticker:"LONGA" ~qty:100.0 ~entry:50.0 ());
        ( "SHORTB",
          _make_holding ~side:Trading_base.Types.Short ~ticker:"SHORTB"
            ~qty:40.0 ~entry:100.0 () );
      ]
  in
  assert_that
    (Screening_notional.initial_long_notional positions)
    (float_equal 5_000.0)

let () =
  run_test_tt_main
    ("entry_audit_capture"
    >::: [
           "G14: effective_entry overrides cand.suggested_entry"
           >:: test_effective_entry_overrides_suggested_entry;
           "G14: build_entry_event audit dollars use effective_entry"
           >:: test_entry_event_audit_dollars_use_effective_entry;
           "G14: empty bar_reader falls back to suggested_entry"
           >:: test_empty_bar_reader_falls_back_to_suggested_entry;
           "G15-step2: short notional cap skips at 31%"
           >:: test_short_notional_cap_skips_at_31pct;
           "G15-step2: short notional cap admits at 29%"
           >:: test_short_notional_cap_admits_at_29pct;
           "G15-step2: short notional cap does not block longs"
           >:: test_short_notional_cap_does_not_block_longs;
           "G15-step2: short notional cap with zero existing"
           >:: test_short_notional_cap_zero_existing;
           "G15-step3: long stop too wide rejects at 20%"
           >:: test_long_stop_too_wide_rejects_at_20pct;
           "G15-step3: short stop too wide rejects at 25%"
           >:: test_short_stop_too_wide_rejects_at_25pct;
           "G15-step3: stop within 15% admits" >:: test_stop_within_15pct_admits;
           "vol-scaled floor over cap rejects"
           >:: test_vol_scaled_floor_over_cap_rejects;
           "vol-scaled floor under cap admits"
           >:: test_vol_scaled_floor_under_cap_admits;
           "G15-step3: sizing uses installed_stop"
           >:: test_sizing_uses_installed_stop;
           "P1: sector exposure cap off passes through"
           >:: test_sector_exposure_cap_off_passes_through;
           "P1: sector exposure cap rejects at 33%"
           >:: test_sector_exposure_cap_rejects_at_33pct;
           "P1: sector exposure cap admits at 25%"
           >:: test_sector_exposure_cap_admits_at_25pct;
           "P1: sector exposure cap exempts empty sector"
           >:: test_sector_exposure_cap_exempts_empty_sector;
           "P1: sector exposure cap accumulates across candidates"
           >:: test_sector_exposure_cap_accumulates_across_candidates;
           "P0b: long notional cap off passes through"
           >:: test_long_notional_cap_off_passes_through;
           "P0b: long notional cap skips at 72%"
           >:: test_long_notional_cap_skips_at_72pct;
           "P0b: long notional cap admits at cap"
           >:: test_long_notional_cap_admits_at_cap;
           "P0b: long notional cap does not block shorts"
           >:: test_long_notional_cap_does_not_block_shorts;
           "P0b: classify emits Long_exposure_cap + refunds cash"
           >:: test_long_exposure_cap_classify_skips_and_refunds;
           "P0b: initial_long_notional seeds from long holdings"
           >:: test_initial_long_notional_seeds_from_long_holdings;
         ])
