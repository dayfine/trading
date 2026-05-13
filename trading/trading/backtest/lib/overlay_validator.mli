(** Validate + apply sweep-overlay sexps onto the canonical
    [Weinstein_strategy.config] base. Closes the silent-no-op hazard from PR
    #1051: an overlay key that does not resolve to a real field on the base
    record now raises [Failure] with the offending overlay index, the unknown
    dot-paths, and the verbatim overlay sexp — rather than being silently
    dropped (which previously produced bit-identical metrics across an 81-cell
    sweep). *)

val apply_overrides :
  Weinstein_strategy.config -> Sexplib.Sexp.t list -> Weinstein_strategy.config
(** [apply_overrides config overrides] deep-merges each overlay in [overrides]
    (left-to-right) into [config]. Raises [Failure] on the first overlay
    containing any key path that does not resolve to a real field on the running
    base record. The error message names the offending overlay index (0-based),
    the dot-paths that did not resolve, and the overlay sexp verbatim, so
    operators can locate the typo in their sweep spec. *)
