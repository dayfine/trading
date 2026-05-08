(** Detects held positions whose underlying symbol has stopped emitting bars —
    see [stale_hold.mli]. *)

open Core

(** {1 Configuration} *)

type config = { enabled : bool; stale_after_days : int }
[@@deriving show, eq, sexp]

let _default_stale_after_days = 5

let default_config =
  { enabled = true; stale_after_days = _default_stale_after_days }

(** {1 Event} *)

type event = {
  symbol : string;
  date : Date.t;
  last_bar_date : Date.t;
  last_close : float;
  days_since_last_bar : int;
  quantity : float;
  cost_basis : float;
}
[@@deriving show, eq, sexp]

(** {1 Detector} *)

let _today_symbol_set today_bars =
  List.map today_bars ~f:(fun bar -> bar.Trading_engine.Types.symbol)
  |> String.Set.of_list

(** Build a stale event for [pos] given its most recent prior bar [prev].
    Returns [None] when the gap is below [stale_after_days]. *)
let _build_stale_event ~date ~stale_after_days
    (pos : Trading_portfolio.Types.portfolio_position)
    (prev : Types.Daily_price.t) : event option =
  let last_bar_date = prev.Types.Daily_price.date in
  let gap = Date.diff date last_bar_date in
  if gap < stale_after_days then None
  else
    let quantity =
      Trading_portfolio.Calculations.position_quantity pos |> Float.abs
    in
    let avg_cost = Trading_portfolio.Calculations.avg_cost_of_position pos in
    Some
      {
        symbol = pos.symbol;
        date;
        last_bar_date;
        last_close = prev.Types.Daily_price.close_price;
        days_since_last_bar = gap;
        quantity;
        cost_basis = avg_cost *. quantity;
      }

(** Build one stale event for a single held position, or [None] when the
    position has a bar today, no prior bar, or the prior bar is recent enough.
    Pure with respect to the adapter's cache. *)
let _event_for_position ~adapter ~date ~today_set ~stale_after_days
    (pos : Trading_portfolio.Types.portfolio_position) : event option =
  if Set.mem today_set pos.symbol then None
  else
    let%bind.Option prev =
      Trading_simulation_data.Market_data_adapter.get_previous_bar adapter
        ~symbol:pos.symbol ~date
    in
    _build_stale_event ~date ~stale_after_days pos prev

let detect_stale ~adapter ~date ~portfolio ~today_bars ~config =
  if not config.enabled then []
  else
    let today_set = _today_symbol_set today_bars in
    List.filter_map portfolio.Trading_portfolio.Portfolio.positions
      ~f:(fun pos ->
        _event_for_position ~adapter ~date ~today_set
          ~stale_after_days:config.stale_after_days pos)

(** {1 Log} *)

module Log = struct
  type t = { mutable rev_events : event list }

  let create () = { rev_events = [] }
  let record t event = t.rev_events <- event :: t.rev_events

  let _compare_event (a : event) (b : event) =
    match Date.compare a.date b.date with
    | 0 -> String.compare a.symbol b.symbol
    | n -> n

  let events t = List.rev t.rev_events |> List.sort ~compare:_compare_event
  let count t = List.length t.rev_events

  let distinct_symbols t =
    events t
    |> List.map ~f:(fun e -> e.symbol)
    |> List.dedup_and_sort ~compare:String.compare
end

(** {1 Sexp persistence} *)

type artefact = { events : event list } [@@deriving sexp]

let save_sexp ~path log =
  match Log.events log with
  | [] -> ()
  | evs ->
      let blob : artefact = { events = evs } in
      Sexp.save_hum path (sexp_of_artefact blob)

let load_sexp path =
  let sexp = Sexp.load_sexp path in
  let blob = artefact_of_sexp sexp in
  blob.events
