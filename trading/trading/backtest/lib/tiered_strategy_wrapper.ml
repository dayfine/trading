(* @large-module: this file integrates three seams (tier bookkeeping, get_price
   throttle, Bar_history seed) plus the Friday cycle orchestration, each of
   which is tightly coupled to the wrapper's closure state. Splitting any one
   concern into a sibling module would fragment the on_market_close flow
   across files. *)

(** Tier-bookkeeping wrapper around a [STRATEGY] — see
    [tiered_strategy_wrapper.mli]. *)

open Core
open Trading_strategy
module Bar_history = Weinstein_strategy.Bar_history

type config = {
  bar_loader : Bar_loader.t;
  bar_history : Bar_history.t;
  universe : string list;
  always_loaded_symbols : String.Set.t;
  seed_warmup_start : Date.t;
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

(** [_seed_from_full t ~symbols] pulls each symbol's [Full.t.bars] from the
    loader and seeds the shared [bar_history] with them. Symbols that aren't at
    Full tier (promotion failed, insufficient history) are silently skipped —
    the wrapper's throttled [get_price] will keep returning [None] for them and
    the strategy will stay oblivious.

    Bars earlier than [t.seed_warmup_start] are truncated out before seeding.
    Matches Legacy's warmup window: [Bar_history.accumulate] under Legacy grows
    from [start_date - warmup_days] forward, so by day D the history holds at
    most [D - warmup_start + 1] daily bars. Full tier's default multi-year tail
    would otherwise give Tiered strictly more history, and
    [Stock_analysis.analyze]'s RS / resistance / MA outputs diverge silently
    when the weekly-bar input count differs. The lower bound on the seed window
    is the correctness fix for that divergence.

    This is the integration's load-bearing primitive: every Full-tier promotion
    pair-fires with a seed, giving the strategy's [Bar_history] readers
    ([_screen_universe], [Stops_runner._compute_ma], [_make_entry_transition])
    the same bars they'd see under Legacy [accumulate]. *)
let _truncate_bars ~cutoff (bars : Types.Daily_price.t list) =
  List.filter bars ~f:(fun b -> Date.( >= ) b.Types.Daily_price.date cutoff)

let _seed_one_symbol t ~cutoff symbol =
  match Bar_loader.get_full t.bar_loader ~symbol with
  | None -> ()
  | Some full ->
      let bars = _truncate_bars ~cutoff full.bars in
      Bar_history.seed t.bar_history ~symbol ~bars

let _seed_from_full t ~symbols =
  let cutoff = t.seed_warmup_start in
  List.iter symbols ~f:(_seed_one_symbol t ~cutoff)

(** [_promote_universe_to_full] promotes every universe symbol in [symbols] to
    Full tier and seeds [bar_history] with each symbol's [Full.t.bars].
    Idempotent for symbols already at Full; per-symbol failures (missing CSV)
    are logged + swallowed via [_promote_each_to].

    Promotes directly to Full rather than gating on Summary. The underlying
    [Bar_loader._promote_one_to_full] treats Summary scalar resolution as
    best-effort — Full promotion succeeds as long as the CSV has at least one
    bar (which implies Metadata succeeded). [Bar_history] gets seeded with
    whatever bars the loader has, matching Legacy's "use whatever bars
    [accumulate] has at this point" invariant. The strategy's per-indicator math
    (Stage classifier, Stock_analysis) already handles short-history inputs by
    returning [None] / skipping the symbol — which is the same behaviour Legacy
    exhibits.

    Memory cost: [Bar_history] grows monotonically to the universe size over the
    simulation (one entry per symbol that has had a successful Metadata promote
    at least once). The [Full.t.bars] cache stays bounded by
    [Full_compute.tail_days], independent of [Bar_history]. *)
let _promote_universe_to_full t ~symbols ~as_of =
  if not (List.is_empty symbols) then (
    _promote_each_to t ~symbols ~to_:Full_tier ~as_of
      ~ctx:"promote universe to Full";
    _seed_from_full t ~symbols)

(** [_run_friday_cycle] promotes every universe symbol to Full and seeds
    [bar_history] from each symbol's [Full.t.bars]. Called once per Friday via
    the wrapper's [on_market_close], {b before} delegating to the inner strategy
    so the Full-tier bars + seeded [bar_history] are visible to the inner
    screener's [_screen_universe] on the same day.

    Parity-fix history (most recent first):

    - {b Pass 3 (this fix)}: drop the intermediate Summary promote pass and
      promote universe symbols straight to Full.
      [Bar_loader.promote ~to_:Full_tier] auto-cascades through Metadata →
      Summary → Full and (after the loader change paired with this fix) treats
      Summary scalar resolution as best-effort. The wrapper now drives Full
      directly and lets the loader's cascade handle the rest. Closes the
      bull-crash residual divergence on the small CI fixture (pre-fix: Tiered
      missed the early entry batch entirely because the Summary tier's RS window
      — [rs_ma_period] weekly bars — hadn't resolved yet, leaving [Bar_history]
      empty for the universe).

    - {b Pass 2 (PR five-one-seven)}: dropped the [Shadow_screener] filter from
      the promote step (it was pre-filtering candidates against Legacy's
      screener cascade, capping at [full_candidate_limit]) and replaced it with
      "promote every Summary-tier symbol to Full". Closed broad-goldens
      multi-fold trade-count divergence; left small-fixture residual that Pass 3
      closes.

    - {b Pass 1 (pre-PR five-one-seven)}: original Shadow_screener-driven design
      (now removed). The shadow's stricter RS gate and missing screener bonuses
      produced a different candidate set than Legacy. *)
let _run_friday_cycle t ~as_of =
  _promote_universe_to_full t ~symbols:t.universe ~as_of

(** [_promote_new_entries] promotes every symbol referenced by a
    [CreateEntering] transition to Full tier and seeds [bar_history] from the
    loader's bars. Ensures the loader has OHLCV ready the first time the
    strategy reads bars for the newly-tracked position on subsequent steps. *)
let _promote_new_entries t ~transitions ~as_of =
  let symbols =
    List.filter_map transitions ~f:(fun (trans : Position.transition) ->
        match trans.kind with
        | CreateEntering { symbol; _ } -> Some symbol
        | _ -> None)
  in
  if not (List.is_empty symbols) then (
    _promote_each_to t ~symbols ~to_:Full_tier ~as_of
      ~ctx:"promote new entries to Full";
    _seed_from_full t ~symbols)

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
    - Everything else resolves to [None]. [Bar_history.accumulate] silently
      skips [None] returns — this is the core memory win. *)
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
    so its Full-tier promotions + seeding are visible to the inner screener on
    the same day. *)
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
     + seeded bar_history are visible to the inner screener the same day. *)
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
