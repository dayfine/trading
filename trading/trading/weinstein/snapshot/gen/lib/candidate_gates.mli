(** The post-sizing gates of {!Weekly_snapshot_generator}, applied to the fully
    decorated long / short pick lists in a fixed order:

    + {!Participation_gate.partition} on the longs (issue #3681): drops a long
      whose sized position exceeds [max_entry_adv_participation] times its
      dollar-ADV. Default off.
    + {!Spike_bar_gate.flag_candidates} on both sides (issue #2083 fix 3):
      flags, never drops. Default off.

    Factored out of the generator so the wiring of each gate lives beside the
    gates rather than in the coordinator. Pure. *)

open Core
open Weinstein_snapshot

val apply :
  config:Weinstein_strategy.config ->
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  longs:Weekly_snapshot.candidate list ->
  shorts:Weekly_snapshot.candidate list ->
  Weekly_snapshot.candidate list * Weekly_snapshot.candidate list * string list
(** [(longs', shorts', warnings)]: the participation warnings first, then the
    long spike warnings, then the short spike warnings. *)
