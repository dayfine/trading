(** Constructor-by-constructor hops from the strategy-layer audit enums
    ({!Weinstein_strategy.Audit_recorder}) to {!Trade_audit}'s on-disk schema
    copies (see [trade_audit.mli] for why the copies exist).

    Each hop is an exhaustive match written out rather than a cast, so a new
    upstream constructor fails the build here — the last point before
    [trade_audit.sexp] where a dropped value would become invisible. Used by
    {!Trade_audit_recorder}; split out of it to keep that file under the
    file-length cap. *)

val stop_floor_kind_of_event :
  Weinstein_strategy.Audit_recorder.stop_floor_kind ->
  Trade_audit.stop_floor_kind
(** [Support_floor] / [Buffer_fallback], one-to-one. *)

val split_safe_basis_of_event :
  Weinstein_strategy.Audit_recorder.split_safe_basis ->
  Trade_audit.split_safe_basis
(** F5 telemetry: which price basis the entry's support-floor scan ran on,
    one-to-one. *)

val skip_reason_of_event :
  Weinstein_strategy.Audit_recorder.skip_reason -> Trade_audit.skip_reason
(** Every entry-walk skip reason, one-to-one (including #3015's
    [Share_class_held]). *)

val entry_anchor_of_kind :
  Screener.entry_anchor_kind -> Ticket_lifecycle.entry_anchor
(** Constructor-by-constructor hop for the #3074 ticket-anchor tag, from
    {!Screener.entry_anchor_kind} to {!Ticket_lifecycle.entry_anchor}. *)
