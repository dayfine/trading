(** Tier-bookkeeping wrapper around a [STRATEGY] — see
    [tiered_strategy_wrapper.mli]. *)

open Core
open Trading_strategy

type config = {
  bar_loader : Bar_loader.t;
  universe : string list;
  screening_config : Screener.config;
  full_candidate_limit : int;
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

(** [_promote_candidates_to_full] takes [buy_candidates @ short_candidates] from
    a [Shadow_screener.result], caps by [full_candidate_limit], and promotes
    those symbols to Full tier. Idempotent for symbols already at Full. *)
let _promote_candidates_to_full t ~(result : Screener.result) ~as_of =
  let combined = result.buy_candidates @ result.short_candidates in
  let capped = _take_n combined t.full_candidate_limit in
  let symbols =
    List.map capped ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
  in
  if not (List.is_empty symbols) then
    Bar_loader.promote t.bar_loader ~symbols ~to_:Full_tier ~as_of
    |> _swallow_err ~ctx:"promote candidates to Full"

(** [_run_friday_cycle] is the Summary-promote → Shadow_screener →
    Full-promote-top-N pipeline. Called once per Friday via the wrapper's
    [on_market_close]. Uses a wrapper-local [prior_stages] table so the shadow
    screener's transition detection is independent from the inner strategy's own
    [prior_stages] — the two tables otherwise fight over writes. *)
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
  (* Step 3: promote the top-N (buy + short) to Full tier. *)
  _promote_candidates_to_full t ~result ~as_of

(** [_promote_new_entries] promotes every symbol referenced by a
    [CreateEntering] transition to Full tier. Ensures the loader has OHLCV ready
    the first time the strategy reads bars for the newly-tracked position on
    subsequent steps. *)
let _promote_new_entries t ~transitions ~as_of =
  let symbols =
    List.filter_map transitions ~f:(fun (trans : Position.transition) ->
        match trans.kind with
        | CreateEntering { symbol; _ } -> Some symbol
        | _ -> None)
  in
  if not (List.is_empty symbols) then
    Bar_loader.promote t.bar_loader ~symbols ~to_:Full_tier ~as_of
    |> _swallow_err ~ctx:"promote new entries to Full"

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

(** [_handle_ok_output] is the per-call bookkeeping body that runs when the
    inner strategy returns [Ok]: stop-log recording, per-Closed demote, Friday
    cycle, per-Entering promote, and the prior-positions snapshot update.
    Factored out of [wrap]'s [on_market_close] so the closure body stays flat.
*)
let _handle_ok_output t ~prior_positions ~shadow_prior_stages ~get_price
    ~portfolio ~(transitions : Position.transition list) =
  Stop_log.record_transitions t.stop_log transitions;
  let as_of = _current_date ~get_price ~primary_index:t.primary_index in
  let closed_symbols =
    _newly_closed_symbols ~prev:!prior_positions
      ~curr:portfolio.Portfolio_view.positions
  in
  _demote_closed t ~symbols:closed_symbols;
  if _is_friday ~get_price ~primary_index:t.primary_index then
    _run_friday_cycle t ~prior_stages:shadow_prior_stages ~portfolio ~as_of;
  _promote_new_entries t ~transitions ~as_of;
  prior_positions := Map.map portfolio.positions ~f:(fun pos -> pos.state)

(** [_on_market_close_wrapped] is the per-call body [wrap]'s [on_market_close]
    delegates to. Extracting it keeps [wrap]'s closure flat — otherwise the
    local module + nested match pushes nesting over the linter's limit. *)
let _on_market_close_wrapped ~inner ~t ~prior_positions ~shadow_prior_stages
    ~get_price ~get_indicator ~portfolio =
  let result = inner ~get_price ~get_indicator ~portfolio in
  (match result with
  | Error _ -> ()
  | Ok { Strategy_interface.transitions } ->
      _handle_ok_output t ~prior_positions ~shadow_prior_stages ~get_price
        ~portfolio ~transitions);
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
