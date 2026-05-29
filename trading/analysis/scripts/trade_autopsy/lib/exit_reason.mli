(** Exit-reason classification for a closed trade.

    Derived from the position of the trade in the strategy's trade list and the
    strategy's mechanic. For the per-symbol stage strategy:
    - All long trades are entered on Stage1→Stage2 and exited on Stage2→Stage3,
      except for the FINAL bar's open position which is force-closed.
    - All short trades are entered on Stage3→Stage4 and exited on Stage4→Stage1,
      with the same end-of-window force-close rule for the tail.

    Pure functions. *)

open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type t =
  | Stage3_exit
      (** Long-only exit on Stage 2→3 transition. Default for non-tail long
          trades. *)
  | Stage1_cover_short
      (** Long-short: cover triggered by Stage 4→1 transition. Default for
          non-tail short trades. *)
  | End_of_period  (** Final-bar force-close (tail trade). *)
  | Stop_out
      (** Stop-loss triggered. NEVER produced under the per-symbol stage
          strategy; reserved for future strategies. *)
  | Stage4_decline
      (** Price entered Stage 4 directly from Stage 2 (skipping Stage 3). NEVER
          produced under the per-symbol stage strategy (Stage1→2→3 is the
          canonical mapping); reserved. *)
  | Laggard_rotation
      (** Cross-sectional rotation expelled the position. Strictly zero for
          per-symbol diagnostic — included for completeness so a single autopsy
          schema covers rotation-aware strategies too. *)
[@@deriving show, eq, sexp]

val derive : final_bar_date:Date.t -> trade:Walk_step.trade -> t
(** [derive ~final_bar_date ~trade] derives the exit reason for [trade]. The
    per-symbol stage strategy has no stops and no Stage4-skip path; those
    exit-reason variants exist for schema completeness but are never produced
    here. Trades whose [exit_date] matches the final bar are force-closes; all
    other long trades exit via Stage 2→3; all other short trades cover via Stage
    4→1. *)
