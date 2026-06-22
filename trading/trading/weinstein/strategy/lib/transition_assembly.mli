(** Exited-position set helpers + final transition-list assembly for the
    Weinstein strategy's per-tick output.

    Extracted from [weinstein_strategy.ml] to keep that coordinator under the
    file-length cap: these are the pure list/set utilities that combine the
    several exit / adjust / entry transition streams a market day produces into
    the single ordered output, dropping adjust/harvest transitions for positions
    already fully exited this tick. *)

open Core
open Trading_strategy

val trigger_exit_ids_of : Position.transition list -> String.Set.t
(** The set of [position_id]s carried by [TriggerExit] transitions in the list
    (non-exit transitions contribute nothing). *)

val filter_out_exited_ids :
  String.Set.t -> Position.transition list -> Position.transition list
(** Drop every transition whose [position_id] is in the exited set. Identity
    when the set is empty. *)

val assemble_output :
  exit_transitions:Position.transition list ->
  stage3_force_exit_transitions:Position.transition list ->
  laggard_rotation_transitions:Position.transition list ->
  force_exit_transitions:Position.transition list ->
  macro_trim_transitions:Position.transition list ->
  harvest_rotate_transitions:Position.transition list ->
  adjust_transitions:Position.transition list ->
  entry_transitions:Position.transition list ->
  stop_exited_ids:String.Set.t ->
  stage3_exited_ids:String.Set.t ->
  laggard_exited_ids:String.Set.t ->
  Strategy_interface.output Status.status_or
(** Combine the per-tick transition streams into the single ordered
    {!Strategy_interface.output}. Adjust and harvest-rotate transitions are
    dropped for any position already fully exited this tick (a stop / Stage-3 /
    laggard / force-liq / macro-bearish exit), since a closing position has
    nothing left to adjust or trim. Always returns [Ok]. *)
