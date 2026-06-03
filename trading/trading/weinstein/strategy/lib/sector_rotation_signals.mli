(** Pure selection helpers for the sector-rotation Weinstein strategy.

    Extracted from [sector_rotation_weinstein_strategy.ml] so the strategy
    module stays under the file-length limit. These functions are pure — no I/O,
    no mutable state — operating on already-read {!Stage.result} / {!Rs.result}
    values. *)

open Core

type candidate = {
  symbol : string;  (** Tradable symbol. *)
  normalized_rs : float;
      (** The symbol's RS vs the benchmark ([Rs.result.current_normalized]); the
          ranking key. *)
}
(** A Stage-2-eligible symbol paired with its RS-ranking score. *)

val is_stage2_advance : Stage.result -> bool
(** True when [r] is a long entry signal — Stage 2 on a rising MA. The same
    predicate {!Spy_only_signals.is_entry_signal} encodes; re-exported here so
    the strategy's eligibility filter reads in selection terms. *)

val rank_top_k : candidates:candidate list -> k:int -> String.Set.t
(** [rank_top_k ~candidates ~k] returns the symbols of the top [k] candidates by
    [normalized_rs] descending, tie-broken by symbol name ascending so the
    selection is deterministic. Returns at most [k] symbols (fewer when
    [candidates] is shorter). A non-positive [k] yields the empty set. *)

val rank_top_k_capped :
  candidates:candidate list ->
  k:int ->
  sector_cap:int option ->
  sector_of:(string -> string option) ->
  String.Set.t
(** [rank_top_k_capped ~candidates ~k ~sector_cap ~sector_of] is {!rank_top_k}
    with an optional per-sector diversification cap.

    When [sector_cap = None] it is exactly {!rank_top_k} (no cap). When
    [sector_cap = Some n] it walks the same RS-descending, symbol-ascending
    order and admits a candidate only while (a) fewer than [k] symbols have been
    picked overall {b and} (b) the candidate's sector currently holds fewer than
    [n] picks. [sector_of sym] resolves a symbol's sector; a symbol that maps to
    [None] is treated as its own singleton sector (keyed by the symbol itself),
    so unmapped names are never capped away.

    The cap is purely a constraint on which of the already-qualified, RS-ranked
    Stage-2 candidates are filled — it does not touch the Weinstein spine
    (Stage-2-only entry, RS-for-selection ordering). See
    [.claude/rules/weinstein-faithful-core.md]. A non-positive [k] yields the
    empty set; a non-positive [n] yields the empty set. *)
