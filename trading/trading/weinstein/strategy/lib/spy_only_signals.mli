(** Pure stage-signal predicates for the SPY-only Weinstein strategy.

    Extracted from [spy_only_weinstein_strategy.ml] so the strategy module stays
    under the file-length limit. Each predicate maps a {!Stage.result} (and, for
    the entry decision, the side configuration) to an enter / exit / cover
    verdict. No I/O, no mutable state — same input, same output. *)

open Trading_strategy

val is_entry_signal : Stage.result -> bool
(** A long entry signal: the symbol is in Stage 2 (advancing) {e and} the MA is
    rising — never a flat-MA basing tape. *)

val stage_exit_label_for_side :
  side:Position.position_side -> Stage.result -> string option
(** The stage-driven exit LABEL for a held position on [side], if the weekly
    read fires one: a LONG exits on a Stage-4 roll-over ([stage4_exit]); a SHORT
    covers when the tape LEAVES Stage 4 ([stage4_cover]). [None] = no
    stage-based exit this tick. *)

val flat_entry_side :
  enable_stage4_short:bool -> Stage.result -> Position.position_side option
(** The flat-tape entry decision for a weekly stage read: a LONG on a Stage-2
    advance, or — only when [enable_stage4_short] is set — a SHORT on a Stage-4
    decline. [None] = stay flat. With the short leg off this collapses to the
    long-only rule, bit-identical to the pre-short-leg strategy. *)
