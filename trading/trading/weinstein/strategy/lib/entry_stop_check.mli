(** The initial-stop half of the entry walk's per-candidate decision, as a pure
    value.

    {!Entry_audit_capture.make_entry_transition} is this check followed by
    sizing and ticket construction ({!Entry_audit_capture.entry_of_stop_check}).
    It is split out so that a caller can ask the walk's own stop question —
    "which initial stop would this candidate get, and would the investor-preset
    gate or the [max_stop_distance_pct] gate turn it away?" — without placing
    anything: {!evaluate} registers no stop state, consumes no position id,
    touches no cash and emits no debug trace. The one consumer outside the walk
    is the [candidates.sexp] top-N view ({!Cascade_trace}), which judges the
    candidates the screener's cap cut with exactly the computation the walk
    applies to the ones it kept. *)

type initial_stops = {
  placed : Weinstein_stops.stop_state;
      (** The stop the ticket would install, at [effective_entry]. *)
  placed_kind : Audit_recorder.stop_floor_kind;
  placed_basis : Audit_recorder.split_safe_basis;
  placed_distance_pct : float;
      (** [|placed - effective_entry| / effective_entry]. *)
  gate_kind : Audit_recorder.stop_floor_kind;
      (** The floor kind the stop-width decisions read: [placed_kind] unless
          [?gate_entry] is given. *)
  gate_distance_pct : float;
      (** The distance the [max_stop_distance_pct] gate compares: equal to
          [placed_distance_pct] unless [?gate_entry] is given, in which case it
          is measured from the stop the ticket would install at that entry. *)
}
(** The ticket's initial stop and what the stop-width decisions read. *)

(** What the two pre-sizing gates decided. *)
type decision =
  | Lacks_structural_stop
      (** [?require_structural_stop] is on and the stop is the
          automatic-percentage fallback ([gate_kind = Buffer_fallback]). Checked
          first, so it takes precedence over the width gate. *)
  | Width of Stop_width_mode.outcome
      (** {!Stop_width_mode.gate} on [gate_distance_pct]: [Drop] is the walk's
          [Stop_too_wide]; [Admit] / [Admit_sized_down] proceed to sizing. *)

type t = {
  decision_bar : Types.Daily_price.t option;
      (** The latest daily bar at the decision, [None] when there is none. *)
  effective_entry : float;
      (** The ticket's trigger: the latest raw close, or the screener's
          [suggested_entry] under [?trigger_at_suggested] or with no bar. *)
  stops : initial_stops;
  max_stop_distance_pct : float;
      (** [stops_config.max_stop_distance_pct], carried for the trace. *)
  decision : decision;
}

val evaluate :
  ?min_stop_distance_pct:float ->
  ?trigger_at_suggested:bool ->
  ?stop_anchor_at_entry_base:bool ->
  ?continuation_stop_at_pullback_low:bool ->
  ?require_structural_stop:bool ->
  ?stop_width:Stop_width_mode.policy ->
  ?gate_entry:float ->
  stops_config:Weinstein_stops.config ->
  initial_stop_buffer:float ->
  bar_reader:Bar_reader.t ->
  current_date:Core.Date.t ->
  Screener.scored_candidate ->
  t
(** Steps (1)-(3) of {!Entry_audit_capture.make_entry_transition}, whose
    docstring defines every optional argument: the effective entry, the
    support-floor-aware initial stop (and, with [?gate_entry], the stop the
    width decisions measure), then the investor-preset gate and the width gate.
    Defaults match that function's, so the default path is unchanged.

    Pure: reads [bar_reader] and nothing else. *)
