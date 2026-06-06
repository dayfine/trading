(** Macro-bearish held-exposure trim. See [macro_bearish_trim_runner.mli]. *)

open Core
open Trading_strategy

(** The exit reason stamped on every trimmed position — a generic
    [StrategySignal] so the position state machine + simulator already handle
    it; the ["macro_bearish_trim"] label surfaces in the [exit_trigger] column
    of trades.csv. *)
let _exit_reason : Position.exit_reason =
  Position.StrategySignal { label = "macro_bearish_trim"; detail = None }

(** Signed long market value of a single [Holding] long position. Returns [None]
    for non-Holding positions, for short positions, and for symbols without a
    price this tick. Long-only by design — the trim caps {e long} exposure; a
    bearish tape is the natural environment for shorts, so they are never
    trimmed here. *)
let _long_market_value ~get_price (pos : Position.t) : float option =
  match (pos.side, pos.state) with
  | Trading_base.Types.Long, Position.Holding { quantity; _ } ->
      Option.map (get_price pos.symbol) ~f:(fun bar ->
          quantity *. bar.Types.Daily_price.close_price)
  | _ -> None

type _candidate = { pos : Position.t; market_value : float; rs : float }
(** A held long position eligible for trimming, with its mark-to-market value
    and RS score (lower = weaker, exited first). Positions without a price or an
    RS read are excluded upstream. *)

(** Build the trim candidate for one position when it is a priced long Holding
    not already exiting via an earlier channel this tick. [rs_ranking] supplies
    the weakest-first sort key (lower = weaker); a position with no RS read is
    skipped (it cannot be ranked against the others). *)
let _candidate_of_position ~get_price ~rs_ranking ~skip_position_ids
    (pos : Position.t) : _candidate option =
  if Set.mem skip_position_ids pos.Position.id then None
  else
    match (_long_market_value ~get_price pos, rs_ranking pos) with
    | Some market_value, Some rs -> Some { pos; market_value; rs }
    | _ -> None

(** Collect the trimmable candidates from [positions], in arbitrary order. Only
    priced long Holdings not on the skip-list with a known RS score qualify. *)
let _collect_candidates ~get_price ~rs_ranking ~skip_position_ids positions =
  Map.fold positions ~init:[] ~f:(fun ~key:_ ~data:pos acc ->
      match
        _candidate_of_position ~get_price ~rs_ranking ~skip_position_ids pos
      with
      | Some c -> c :: acc
      | None -> acc)

(** Build the [TriggerExit] transition closing the entire position at the
    current bar close ([exit_price = bar.close_price]). [bar] is the candidate's
    already-fetched price bar, so no [get_price] round-trip is needed here. *)
let _exit_transition ~current_date (pos : Position.t)
    (bar : Types.Daily_price.t) : Position.transition =
  {
    Position.position_id = pos.id;
    date = current_date;
    kind =
      Position.TriggerExit
        { exit_reason = _exit_reason; exit_price = bar.close_price };
  }

(** One step of the weakest-first trim fold: while held exposure is still above
    [target_value], exit the next candidate (subtracting its value); otherwise
    leave the running state unchanged. [get_price] is guaranteed [Some] here —
    the candidate was only built when a price existed — so the [None] branch is
    defensive. *)
let _trim_step ~get_price ~current_date ~target_value (remaining, acc)
    (c : _candidate) =
  if Float.( <= ) remaining target_value then (remaining, acc)
  else
    match get_price c.pos.symbol with
    | None -> (remaining, acc)
    | Some bar ->
        ( remaining -. c.market_value,
          _exit_transition ~current_date c.pos bar :: acc )

(** Walk the weakest-first candidate list, exiting positions until the remaining
    held long exposure is at or below [target_value]. [held] is the total long
    market value before trimming. Returns the exit transitions in trim order. *)
let _trim_to_target ~get_price ~current_date ~target_value ~held candidates =
  let _remaining, transitions =
    List.fold candidates ~init:(held, [])
      ~f:(_trim_step ~get_price ~current_date ~target_value)
  in
  List.rev transitions

(** Decide the trim for an already-collected candidate set. No-op ([[]]) when
    held long exposure is at or below the cap; otherwise orders weakest-RS-first
    and trims down to [target_value]. *)
let _trim_candidates ~get_price ~current_date ~target_value candidates =
  let held =
    List.fold candidates ~init:0.0 ~f:(fun acc c -> acc +. c.market_value)
  in
  if Float.( <= ) held target_value then []
  else
    List.sort candidates ~compare:(fun a b -> Float.compare a.rs b.rs)
    |> _trim_to_target ~get_price ~current_date ~target_value ~held

let update ~max_long_exposure_pct ~portfolio_value ~positions ~get_price
    ~rs_ranking ~skip_position_ids ~current_date =
  if Float.( <= ) portfolio_value 0.0 then []
  else
    let target_value = max_long_exposure_pct *. portfolio_value in
    let candidates =
      _collect_candidates ~get_price ~rs_ranking ~skip_position_ids positions
    in
    _trim_candidates ~get_price ~current_date ~target_value candidates
