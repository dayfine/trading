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
  screening_config : Screener.config;
  full_candidate_limit : int;
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

(** [_summary_values_of s] projects a [Bar_loader.Summary.t] onto the
    [summary_values] record the [Shadow_screener] consumes. Separated out so
    [_summaries_for] stays a flat filter_map over the loader state. *)
let _summary_values_of (s : Bar_loader.Summary.t) :
    Bar_loader.Summary_compute.summary_values =
  {
    ma_30w = s.ma_30w;
    atr_14 = s.atr_14;
    rs_line = s.rs_line;
    stage = s.stage;
    as_of = s.as_of;
  }

(** [_summaries_for t ~universe] extracts [(symbol, summary_values)] pairs for
    every symbol in [universe] that the loader has at Summary tier or higher.
    Symbols at Metadata tier (insufficient history for the tail window) or
    absent from the loader are silently dropped — the [Shadow_screener] only
    wants the ones it can actually score. *)
let _summaries_for (bar_loader : Bar_loader.t) ~universe :
    (string * Bar_loader.Summary_compute.summary_values) list =
  List.filter_map universe ~f:(fun symbol ->
      Bar_loader.get_summary bar_loader ~symbol
      |> Option.map ~f:(fun s -> (symbol, _summary_values_of s)))

(** [_take_n xs n] is a head-trimmed prefix of [xs]. Used to cap the candidate
    list by [full_candidate_limit] without materializing the full tail. *)
let _take_n xs n =
  if n <= 0 then []
  else
    let rec loop acc k = function
      | [] -> List.rev acc
      | _ when k = 0 -> List.rev acc
      | x :: rest -> loop (x :: acc) (k - 1) rest
    in
    loop [] n xs

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

(** [_friday_promote_set ~summaries ~result ~full_candidate_limit] chooses which
    Summary-tier symbols to promote to Full tier on a Friday cycle.

    Promotes {e every} Summary-tier symbol in [summaries], capped at
    [full_candidate_limit]. The shadow screener's candidate order is used to
    prioritize the cap — shadow candidates go first (buy then short), then
    remaining Summary-tier symbols in input order.

    Rationale: the shadow cascade is more restrictive than Legacy's own screener
    on several axes documented in [shadow_screener.mli] (Volume synthesis is
    always Adequate, Resistance is None, RS crossover absent). A symbol Legacy
    would enter via [is_breakout_candidate] can fail the shadow cascade yet
    still be a legitimate Stage 2 breakout in inner's fresh
    [Stock_analysis.analyze]. If we only Full-promote shadow's picks, inner
    never sees that symbol's bars and can't enter — trade-count divergence.

    The cap is still load-bearing for broad universes: ~2k Summary-tier symbols
    exist on a 10k universe, and without the cap we'd Full-promote all of them
    and defeat the tiered memory savings. Shadow's ranking is what decides which
    get the Full slots. If the cap is smaller than the Summary-tier count, inner
    only sees a subset — same trade-off as Legacy with a bigger
    [max_buy_candidates + max_short_candidates] cap would have applied at the
    final post-rank stage. *)
let _friday_promote_set ~(summaries : (string * _) list)
    ~(result : Screener.result) ~full_candidate_limit : string list =
  let shadow_tickers =
    List.map (result.buy_candidates @ result.short_candidates)
      ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
  in
  let all_summary = List.map summaries ~f:fst in
  let shadow_set = String.Set.of_list shadow_tickers in
  let non_shadow =
    List.filter all_summary ~f:(fun s -> not (Set.mem shadow_set s))
  in
  (* Shadow picks first (their ranking is already by score), then fill
     remaining slots with the rest of Summary in loader order. *)
  _take_n (shadow_tickers @ non_shadow) full_candidate_limit

(** [_promote_candidates_to_full] resolves the Friday promote set (see
    {!_friday_promote_set}) and promotes each chosen symbol to Full tier.
    Idempotent for symbols already at Full. Seeds [bar_history] from the
    loader's [Full.t.bars] for every promoted symbol. *)
let _promote_candidates_to_full t ~summaries ~(result : Screener.result) ~as_of
    =
  let symbols =
    _friday_promote_set ~summaries ~result
      ~full_candidate_limit:t.full_candidate_limit
  in
  if not (List.is_empty symbols) then (
    Bar_loader.promote t.bar_loader ~symbols ~to_:Full_tier ~as_of
    |> _swallow_err ~ctx:"promote candidates to Full";
    _seed_from_full t ~symbols)

(** [_run_friday_cycle] is the Summary-promote → Shadow_screener →
    Full-promote-top-N pipeline. Called once per Friday via the wrapper's
    [on_market_close], {b before} delegating to the inner strategy so the
    Full-tier bars + seeded [bar_history] are visible to the inner screener's
    [_screen_universe] on the same day. Uses a wrapper-local [prior_stages]
    table so the shadow screener's transition detection is independent from the
    inner strategy's own [prior_stages] — the two tables otherwise fight over
    writes. *)
let _run_friday_cycle t ~prior_stages ~portfolio ~as_of =
  (* Step 1: promote every universe symbol to Summary. Per promote contract,
     symbols with insufficient history stay at Metadata — no error surface. *)
  Bar_loader.promote t.bar_loader ~symbols:t.universe ~to_:Summary_tier ~as_of
  |> _swallow_err ~ctx:"promote universe to Summary";
  (* Step 2: collect summaries and run shadow cascade. Sector map is empty
     because building one requires bar history we deliberately don't hold at
     the Tiered level; the screener defaults missing sectors to Neutral. *)
  let summaries = _summaries_for t.bar_loader ~universe:t.universe in
  let sector_map = Hashtbl.create (module String) in
  let held_tickers = Weinstein_strategy.held_symbols portfolio in
  let result =
    Bar_loader.Shadow_screener.screen ~summaries ~config:t.screening_config
      ~macro_trend:Weinstein_types.Neutral ~sector_map ~prior_stages
      ~held_tickers ~as_of
  in
  (* Step 3: promote the union of shadow candidates + Summary-tier breakout
     precursors (Stage2/Stage4) to Full tier, and seed the shared
     [bar_history] with their OHLCV so the inner screener can read weekly
     bars for them immediately. The precursor axis is what lets parity hold
     on the synthetic fixture, where shadow's RS-gate produces no candidates
     but Stage 2 classification still fires. *)
  _promote_candidates_to_full t ~summaries ~result ~as_of

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
    Bar_loader.promote t.bar_loader ~symbols ~to_:Full_tier ~as_of
    |> _swallow_err ~ctx:"promote new entries to Full";
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
let _on_market_close_wrapped ~inner ~t ~prior_positions ~shadow_prior_stages
    ~get_price ~get_indicator ~portfolio =
  (* Friday cycle fires before the inner strategy so its Full-tier promotions
     + seeded bar_history are visible to the inner screener the same day. *)
  if _is_friday ~get_price ~primary_index:t.primary_index then
    _run_friday_cycle t ~prior_stages:shadow_prior_stages ~portfolio
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
  (* [shadow_prior_stages] is the wrapper-local prior-stage table for the
     Shadow_screener. Kept separate from the inner strategy's own prior_stages
     closure so the two shadowings don't overwrite each other. *)
  let shadow_prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let module Wrapped = struct
    let name = S.name

    let on_market_close =
      _on_market_close_wrapped ~inner:S.on_market_close ~t ~prior_positions
        ~shadow_prior_stages
  end in
  (module Wrapped : Strategy_interface.STRATEGY)
