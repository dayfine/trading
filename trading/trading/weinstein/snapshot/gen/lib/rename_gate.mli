(** Bar-reader adapter for {!Rename_detector} — issue #2083 fix 2.

    {!Rename_detector} is pure by contract: it takes price series, never a bar
    source. This module is the thin layer that reads those series out of a
    {!Weinstein_strategy.Bar_reader.t} and turns a detection report into the
    [(eligible, warnings)] pair {!Weekly_snapshot_generator} consumes — the same
    shape {!Sparse_tail_gate.partition} returns, so the two #2083 eligibility
    stages compose uniformly.

    Engineering data-hygiene wiring, {b not} a Weinstein book rule: no book
    section is cited (none supports it) and the Weinstein spine — stage
    classification, the Stage-2-only buy rule, volume confirmation, entry, stop
    and sizing — is untouched.

    {1 Default-off}

    Both knobs default to their disabling value
    ([config.rename_detect_min_overlap_days = 0],
    [config.rename_detect_match_fraction = 0.0]), and {!partition} returns
    [(tickers, [])] {b before loading any series}, so an unarmed run is
    bit-identical to pre-#2083-fix2 behaviour and costs nothing extra. *)

open Core

val series_for :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  symbol:string ->
  Rename_detector.series
(** [series_for bar_reader ~as_of ~symbol] is [symbol]'s full adjusted-close
    history up to and including [as_of], in the shape {!Rename_detector.detect}
    consumes. A symbol with no resident bars yields an empty [closes] array
    (which the detector then ignores). *)

val partition :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  min_overlap_days:int ->
  match_fraction:float ->
  string list ->
  string list * string list
(** [partition bar_reader ~as_of ~min_overlap_days ~match_fraction tickers] runs
    {!Rename_detector.detect} over every ticker's series and returns
    [(surviving, warnings)]: [tickers] with each detected predecessor removed
    (order preserved, successors kept), and one warning line per detected
    succession naming both tickers, the changeover date and the evidence.

    When either knob is at its disabling value ([min_overlap_days <= 0] or
    [match_fraction <= 0.0], the config defaults) this is [(tickers, [])] and no
    series is read — see {!Rename_detector.Config.armed}.

    Only symbols in [tickers] can be matched against each other, so a successor
    absent from the caller's universe is invisible; see {!Rename_detector}
    §"Known coverage limit". *)
