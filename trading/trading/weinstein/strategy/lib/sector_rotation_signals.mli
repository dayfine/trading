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
