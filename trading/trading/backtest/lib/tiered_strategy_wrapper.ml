(* @large-module: this file integrates two seams (tier bookkeeping +
   get_price throttle) plus the Friday cycle orchestration, each of which is
   tightly coupled to the wrapper's closure state. Splitting any one concern
   into a sibling module would fragment the on_market_close flow across
   files. *)

(** Tier-bookkeeping wrapper around a [STRATEGY] — see
    [tiered_strategy_wrapper.mli]. *)

open Core
open Trading_strategy

type config = {
  bar_loader : Bar_loader.t;
  universe : string list;
  always_loaded_symbols : String.Set.t;
  stop_log : Stop_log.t;
  primary_index : string;
}

(** [_is_friday ~get_price ~primary_index] reads today's primary index bar and
    checks whether its date is a Friday. Same Friday-detection heuristic
    [Weinstein_strategy] uses internally — when the benchmark bar is missing we
    default to [false] (no promotion that day), matching [_is_screening_day]'s
    behaviour in [weinstein_strategy.ml]. *)
let _is_friday ~(get_price : Strategy_interface.get_price_fn) ~primary_index =
  match get_price primary_index with
  | None -> false
  | Some bar ->
      Date.day_of_week bar.Types.Daily_price.date
      |> Day_of_week.equal Day_of_week.Fri

(** [_current_date] reads today's date from the primary index bar. When the
    benchmark bar is missing we fall back to [Date.today] so the wrapper can
    still make a forward-progress decision — this path is only exercised on days
    the strategy itself would consider degenerate. *)
let _current_date ~(get_price : Strategy_interface.get_price_fn) ~primary_index
    =
  match get_price primary_index with
  | Some bar -> bar.Types.Daily_price.date
  | None -> Date.today ~zone:Time_float.Zone.utc

(** [_swallow_err ~ctx result] logs a promote failure to stderr and returns
    unit. A single symbol's load failure must not abort the backtest — the
    loader contract says failed symbols are simply absent from [entries]. *)
let _swallow_err ~ctx = function
  | Ok () -> ()
  | Error (err : Status.t) ->
      eprintf
        "Tiered_strategy_wrapper: [%s] Bar_loader.promote error (continuing): %s\n\
         %!"
        ctx (Status.show err)

(** [_promote_each_to t ~symbols ~to_ ~as_of ~ctx] promotes each symbol
    individually, swallowing per-symbol errors with the same [_swallow_err]
    pattern.

    Why per-symbol rather than the natural batch
    [Bar_loader.promote ~symbols:t.universe ~to_:Summary_tier]:
    [Bar_loader.promote] uses [_promote_fold] which short-circuits on the FIRST
    per-symbol error, leaving every subsequent symbol in the batch unpromoted.
    On a broad universe with thousands of symbols (several with missing CSVs at
    varying alphabet positions), one missing CSV early in the batch silently
    drops every later symbol — observed as a steady decline in Tiered's
    effective candidate pool over the simulation, and a major trade-count
    divergence against Legacy on small-universe bull-crash before this fix.

    Mirrors the per-symbol pattern in [Tiered_runner.promote_universe_metadata]
    (which already learned the same lesson for Metadata promotion) but
    generalized so the wrapper can reuse the shape for both Summary and Full
    promotion in [_run_friday_cycle]. *)
let _promote_each_to t ~symbols ~to_ ~as_of ~ctx =
  List.iter symbols ~f:(fun symbol ->
      Bar_loader.promote t.bar_loader ~symbols:[ symbol ] ~to_ ~as_of
      |> _swallow_err ~ctx)

(** [_promote_universe_to_full] promotes every universe symbol in [symbols] to
    Full tier. Idempotent for symbols already at Full; per-symbol failures
    (missing CSV) are logged + swallowed via [_promote_each_to].

    Promotes directly to Full rather than gating on Summary. The underlying
    [Bar_loader._promote_one_to_full] treats Summary scalar resolution as
    best-effort — Full promotion succeeds as long as the CSV has at least one
    bar (which implies Metadata succeeded).

    The data-panels Stage cleanup deleted the parallel [Bar_history] cache and
    the Friday-cycle seed step that fed it from [Full.t.bars]. The strategy now
    reads bars directly from {!Data_panel.Bar_panels} (populated up-front from
    CSV at runner start), so the Full-tier promote drives loader bookkeeping and
    trace events but no longer feeds an external cache. *)
let _promote_universe_to_full t ~symbols ~as_of =
  if not (List.is_empty symbols) then
    _promote_each_to t ~symbols ~to_:Full_tier ~as_of
      ~ctx:"promote universe to Full"

(** [_run_friday_cycle] promotes every universe symbol to Full. Called once per
    Friday via the wrapper's [on_market_close], {b before} delegating to the
    inner strategy. *)
let _run_friday_cycle t ~as_of =
  _promote_universe_to_full t ~symbols:t.universe ~as_of

(** [_promote_new_entries] promotes every symbol referenced by a
    [CreateEntering] transition to Full tier. Ensures the loader has OHLCV ready
    (in case a future tier-aware reader needs it) the first time the strategy
    enters a new position. *)
let _promote_new_entries t ~transitions ~as_of =
  let symbols =
    List.filter_map transitions ~f:(fun (trans : Position.transition) ->
        match trans.kind with
        | CreateEntering { symbol; _ } -> Some symbol
        | _ -> None)
  in
  if not (List.is_empty symbols) then
    _promote_each_to t ~symbols ~to_:Full_tier ~as_of
      ~ctx:"promote new entries to Full"

(** [_is_newly_closed ~prev id pos] — a position is newly closed iff its current
    state is [Closed] AND the previous snapshot either didn't know the id or had
    it in a non-[Closed] state. Keyed by position_id because a symbol can cycle
    Closed → fresh [Entering] under a new id. *)
let _is_newly_closed ~(prev : Position.position_state String.Map.t) id
    (pos : Position.t) =
  match pos.state with
  | Closed _ -> (
      match Map.find prev id with
      | Some (Closed _) -> false (* already demoted on a prior step *)
      | Some _ | None -> true)
  | Entering _ | Holding _ | Exiting _ -> false

(** [_newly_closed_symbols ~prev ~curr] diffs the previous portfolio positions
    against the current one and returns the symbols whose state has become
    [Closed] since the previous call. Symbols returned here are what the wrapper
    should demote to Metadata. *)
let _newly_closed_symbols ~(prev : Position.position_state String.Map.t)
    ~(curr : Position.t String.Map.t) : string list =
  Map.fold curr ~init:[] ~f:(fun ~key:id ~data:pos acc ->
      if _is_newly_closed ~prev id pos then pos.symbol :: acc else acc)

(** [_demote_closed t ~symbols] demotes every closed symbol to Metadata.
    Idempotent when called twice on the same symbol. *)
let _demote_closed t ~symbols =
  if not (List.is_empty symbols) then
    Bar_loader.demote t.bar_loader ~symbols ~to_:Metadata_tier

(** [_held_symbols_set portfolio] returns the currently-held symbol set as a
    [String.Set.t] — we use set membership in the throttle hot path so [O(1)]
    lookup matters. Closed positions are excluded, matching
    [Weinstein_strategy.held_symbols]. *)
let _held_symbols_set (portfolio : Portfolio_view.t) =
  Weinstein_strategy.held_symbols portfolio |> String.Set.of_list

(** [_throttled_get_price t ~get_price ~portfolio] constructs the inner
    strategy's view of [get_price]:

    - Symbols in [t.always_loaded_symbols] (primary index, sector ETFs, global
      indices) always pass through unchanged. These are structurally required
      every day for day-of-week detection, the sector map, and the macro
      global-consensus indicator.
    - Symbols currently at [Full_tier] pass through. The Friday cycle and
      per-[CreateEntering] promote ensure this covers the symbols the strategy
      cares about on the day it needs them.
    - Symbols currently held in the portfolio pass through regardless of tier.
      In practice every held position is also at Full (we promote on
      [CreateEntering]); this is belt-and-braces against a bookkeeping drift
      where the two would otherwise diverge.
    - Everything else resolves to [None]. The strategy's [get_price]-driven
      paths (day-of-week detection, fallback bar lookups) treat [None] as "no
      bar today", so blocking metadata-tier symbols here keeps the inner
      strategy from acting on data it shouldn't see. *)
let _throttled_get_price t ~(get_price : Strategy_interface.get_price_fn)
    ~(portfolio : Portfolio_view.t) : Strategy_interface.get_price_fn =
  let held = _held_symbols_set portfolio in
  fun symbol ->
    if Set.mem t.always_loaded_symbols symbol then get_price symbol
    else
      match Bar_loader.tier_of t.bar_loader ~symbol with
      | Some Full_tier -> get_price symbol
      | _ -> if Set.mem held symbol then get_price symbol else None

(** [_handle_ok_output] is the per-call bookkeeping body that runs {b after} the
    inner strategy returns [Ok]: stop-log recording, per-Closed demote,
    per-Entering promote, and the prior-positions snapshot update. The Friday
    cycle has already fired {b before} the inner strategy (in [wrap]'s closure)
    so its Full-tier promotions are visible to the inner screener on the same
    day. *)
let _handle_ok_output t ~prior_positions ~get_price ~portfolio
    ~(transitions : Position.transition list) =
  Stop_log.record_transitions t.stop_log transitions;
  let as_of = _current_date ~get_price ~primary_index:t.primary_index in
  let closed_symbols =
    _newly_closed_symbols ~prev:!prior_positions
      ~curr:portfolio.Portfolio_view.positions
  in
  _demote_closed t ~symbols:closed_symbols;
  _promote_new_entries t ~transitions ~as_of;
  prior_positions := Map.map portfolio.positions ~f:(fun pos -> pos.state)

(** [_on_market_close_wrapped] is the per-call body [wrap]'s [on_market_close]
    delegates to. Runs the Friday cycle pre-inner, constructs the throttled
    [get_price'], delegates to inner, then runs post-inner bookkeeping.
    Extracting it keeps [wrap]'s closure flat — otherwise the local module +
    nested match pushes nesting over the linter's limit. *)
let _on_market_close_wrapped ~inner ~t ~prior_positions ~get_price
    ~get_indicator ~portfolio =
  (* Friday cycle fires before the inner strategy so its Full-tier promotions
     are visible to the inner screener the same day. *)
  if _is_friday ~get_price ~primary_index:t.primary_index then
    _run_friday_cycle t
      ~as_of:(_current_date ~get_price ~primary_index:t.primary_index);
  let get_price' = _throttled_get_price t ~get_price ~portfolio in
  let result = inner ~get_price:get_price' ~get_indicator ~portfolio in
  (match result with
  | Error _ -> ()
  | Ok { Strategy_interface.transitions } ->
      _handle_ok_output t ~prior_positions ~get_price ~portfolio ~transitions);
  result

let wrap ~config:t (module S : Strategy_interface.STRATEGY) =
  (* [prior_positions] is the wrapper-local memory of each position's state
     from the previous call — used to detect transitions into [Closed]. *)
  let prior_positions : Position.position_state String.Map.t ref =
    ref String.Map.empty
  in
  let module Wrapped = struct
    let name = S.name

    let on_market_close =
      _on_market_close_wrapped ~inner:S.on_market_close ~t ~prior_positions
  end in
  (module Wrapped : Strategy_interface.STRATEGY)
