(** Deterministic whole-surface trace of the public stops API.

    Prints one line per call, with every float in [%.17g] so a one-ULP shift is
    visible. The companion golden ([stops_surface_trace.expected], diffed by the
    [runtest] rule in this directory's [dune]) is the regression pin: any change
    to default-path stop behaviour — including a refactor that only reassociates
    arithmetic — moves at least one line.

    {b Why this exists (issue #2503).} PR #2492 bundled a [Stop_geometry]
    extraction with its default-off flag. The extraction moved [bar_extreme],
    [nudge_round_number], the two buffered stop candidates, [is_better_stop],
    [is_correction] and [is_recovery] out of [weinstein_stops.ml], and repointed
    [floor_stop.ml]'s local nudge adapter at the new module. Reassociating a
    multiply / round / [Float.min] chain can shift a stop by one ULP, which is
    enough to flip a StopLimit fill and change which symbols a backtest enters.
    The proof that it did not is this trace, generated at the merge-base
    ([3782920a]) and byte-compared against HEAD; the golden is the merge-base
    output, so it also pins every future refactor.

    {b Coverage.} Every [val] in [weinstein_stops.mli] apart from the
    re-exported sub-modules ([Stop_split_adjust], [Stop_widen],
    [Vol_scaled_stop], [Catastrophic_stop], [Extension_stop]) — those were
    untouched by #2492 and are traced only where the functions below reach them
    (they do not). Only the public API is used: no field of [config] added after
    the merge-base may be named here, or the trace could not be generated on
    both sides. *)

open Trace_common

let () =
  line "# stops public-surface trace v1";
  Trace_initial_hit.trace_initial_stops ();
  Trace_initial_hit.trace_stop_hits ();
  Trace_floor.trace_floor_path ();
  Trace_update.trace_update ()
