open Core

(** The Weinstein strategy's per-run mutable state, lifted out of the
    {!Weinstein_strategy.make} closure into one explicit record (#3477).

    Factored out of [Weinstein_strategy] to keep that coordinator file within
    the declared-large file-length limit. {!init} builds the empty state
    ({!Weinstein_strategy.make} uses it, so its behaviour is unchanged);
    {!capture} / {!restore} round-trip the state through a sexp so a backtest
    can resume mid-run via {!Weinstein_strategy.make_with_state}.

    Not state: the A-D and breadth series, the weekly MA cache and the sidetable
    memo are read-only or rebuildable from the run's inputs, so they are rebuilt
    on resume rather than saved. *)

type t = {
  stop_states : Weinstein_stops.stop_state String.Map.t ref;
  last_stop_out_dates : Date.t Hashtbl.M(String).t;
  prior_macro : Weinstein_types.market_trend ref;
  peak_tracker : Portfolio_risk.Force_liquidation.Peak_tracker.t;
  prior_macro_result : Macro.result option ref;
  prior_decline_character : Decline_character.t ref;
  prior_stages : Weinstein_types.stage Hashtbl.M(String).t;
  prior_stage_ma_values : float Hashtbl.M(String).t;
  sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t;
  stage3_streaks : int Hashtbl.M(String).t;
  laggard_streaks : int Hashtbl.M(String).t;
  pending_entry_e : Entry_freeze.t;  (** No-chase [E] pins. *)
  suspended_tickets : Entry_ticket_suspend.t;  (** Stashed resting tickets. *)
}
(** One field per piece of state the [on_market_close] hot path reads or writes
    across ticks. *)

val init : initial_stop_states:Weinstein_stops.stop_state String.Map.t -> t
(** A fresh state: every table empty, [initial_stop_states] seeding the stop
    map, the macro trend [Neutral], the peak tracker at its empty value. Pure
    allocation. *)

type snapshot [@@deriving sexp]
(** The state as plain data: tables become key-sorted association lists (the
    sexp is independent of hash-bucket order) and the peak tracker becomes its
    peak and halt state. It also carries the process-global position-id counter
    ({!Entry_audit_capture.position_counter}) that mints [SYM-wein-N] ids. *)

val capture : t -> snapshot
(** [capture t] copies the state out; [t] is untouched. *)

val restore : snapshot -> t
(** [restore snap] is a fresh state equal to the captured one, so
    [capture (restore s) = s]. It also sets the process-global position-id
    counter ({!Entry_audit_capture.set_position_counter}), so the next minted id
    continues where the captured run stopped. *)
