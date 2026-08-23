(** Per-Friday candidate capture for the [candidates.sexp] artefact (#2490).

    Owns the two things {!Weinstein_strategy_screening.screen_universe} would
    otherwise have to carry inline — a parking slot for what the entry walk
    passed over, and the construction of the Friday's
    {!Audit_recorder.cascade_event}. It lives in its own module because that
    coordinator sits at the file-length cap and its screen function at the
    function-length cap, so the capture had nowhere to go
    ([.claude/rules/code-health-discipline.md]: extract, do not raise the
    limit).

    The whole module is {b inert} unless the recorder opted into capture: the
    handle installs no callback, the strategy computes no projection, and the
    emitted event carries empty lists — bit-identical to the pre-#2490 path. *)

type t

val create : Audit_recorder.t -> t
(** A capture handle for one Friday. Inert when [recorder.capture_candidates] is
    [false], which is the default and every non-audit context. *)

val on_walk_candidates :
  t -> (Audit_recorder.alternative_input list -> unit) option
(** Pass straight to {!Entry_walk.entries_from_candidates}'s
    [?on_candidates_considered]. [None] when inert, so the entry walk never
    computes the projection. *)

val record :
  t ->
  audit_recorder:Audit_recorder.t ->
  date:Core.Date.t ->
  diagnostics:Screener.cascade_diagnostics ->
  entered:int ->
  unit
(** Build this Friday's {!Audit_recorder.cascade_event} from [diagnostics],
    [entered], and whatever {!on_walk_candidates} captured, and route it through
    [audit_recorder.record_cascade_summary].

    Call once per screened Friday, {b after} the entry walk — [entered] must
    count the transitions actually emitted, not the screener's top-N. *)
