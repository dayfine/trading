(** Spike-bar "data-suspect" report-hygiene flag for
    {!Weekly_snapshot_generator} (issue #2083 fix 3).

    {1 What this closes}

    An engineering data-hygiene flag, {b not} a Weinstein book rule — no
    [weinstein-book-reference.md] section supports it, and none is cited. The
    Weinstein spine (stage classification, the Stage-2-only buy rule, breakout +
    volume confirmation, macro / sector gating, stop placement) is untouched by
    this module: it neither admits nor rejects a candidate and never moves an
    entry, stop, or size. It only annotates.

    2026-07-17 incident (issue #2083): the weekly report's rank-1 pick "SNSE"
    was a renamed / dead ticker whose feed served sparse zombie bars, one of
    which printed [+58%] in a single day. The screener consumed that spike as a
    breakout and produced a $36.94 entry on a name trading near $26. Fix 1
    ({!Sparse_tail_gate}) and fix 2 (rename tracking) attack the data source.
    This is the last-line {b report-hygiene backstop}: even when a spike bar is
    genuine and the ticker is alive, a candidate whose signal rests on a single
    outsized bar deserves a visible caveat on the ticket before a human places
    the order.

    {1 What it does}

    {!check} compares the last daily bar at/before [as_of] against the
    {i prior bar's} close (the prior bar in the symbol's resident series — which
    on a sparse / zombie feed is not necessarily the prior trading day; that is
    the point) and reports the {b absolute} percentage move. A move of at least
    [threshold_pct] percentage points is {!Data_suspect}.

    {b Flag, do not drop.} Unlike {!Sparse_tail_gate}, a {!Data_suspect} verdict
    does not remove the candidate: {!Weekly_snapshot_generator} keeps it in the
    ranked list, sets {!Weekly_snapshot.candidate.data_suspect}, and appends
    {!warning} to {!Weekly_snapshot.t.warnings} so the report marks the row and
    explains the marker.

    {1 Default-off}

    [threshold_pct <= 0.0] always returns {!Clean} — the flag is disabled.
    {!Weekly_snapshot_generator} threads
    {!Weinstein_strategy_config.config.spike_bar_threshold_pct}, which defaults
    to [0.0], so an unarmed run is bit-identical to pre-#2083-fix3 behaviour:
    every candidate carries [data_suspect = false] and no spike warning is
    emitted (experiment-flag-discipline R1). *)

open Core

(** [Clean] — the flag is disabled, the symbol has fewer than two resident bars,
    or the last bar's move is under the threshold.
    [Data_suspect { move_pct; threshold_pct; bar_date }] — the flag is armed and
    the last bar moved [move_pct] percentage points (absolute, so a [-58%] crash
    bar reports [58.0]) vs the prior bar's close, at or above [threshold_pct].
    [bar_date] is the date of the offending (last) bar. *)
type verdict =
  | Clean
  | Data_suspect of {
      move_pct : float;
      threshold_pct : float;
      bar_date : Date.t;
    }
[@@deriving eq, show]

val check :
  Weinstein_strategy.Bar_reader.t ->
  symbol:string ->
  as_of:Date.t ->
  threshold_pct:float ->
  verdict
(** [check bar_reader ~symbol ~as_of ~threshold_pct] is {!Clean} when
    [threshold_pct <= 0.0] (flag disabled), when [symbol] has fewer than two
    daily bars at/before [as_of] (nothing to compare against — the sparse-tail
    gate owns the "not enough data" surface), when the prior bar's close is
    [0.0] (undefined percentage move), or when
    [|last.close - prior.close| / prior.close * 100 < threshold_pct]. Otherwise
    {!Data_suspect}, carrying that move.

    The comparison is against the prior bar {i present in the series}, not the
    prior calendar trading day: a zombie feed that skips ten sessions and then
    prints one outsized bar is exactly the case this flags. Pure: same inputs ->
    same output ([bar_reader] is read-only). *)

val flag_candidates :
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  threshold_pct:float ->
  Weinstein_snapshot.Weekly_snapshot.candidate list ->
  Weinstein_snapshot.Weekly_snapshot.candidate list * string list
(** [flag_candidates bar_reader ~as_of ~threshold_pct candidates] applies
    {!check} to each candidate's symbol and returns [(candidates', warnings)].

    {b Flag, do not drop}: [candidates'] has the same length and order as
    [candidates] — a {!Data_suspect} candidate simply comes back with
    {!Weekly_snapshot.candidate.data_suspect}[ = true]; its rank, entry, stop
    and sizing are untouched. [warnings] carries one {!warning} line per flagged
    candidate, in the same order.

    With the flag disabled ([threshold_pct <= 0.0], the default) this is the
    identity on [candidates] with [warnings = []]. Pure. *)

val warning : symbol:string -> verdict -> string option
(** [warning ~symbol verdict] is [None] for {!Clean}. For {!Data_suspect} it is
    [Some msg], a human-readable single line naming the symbol, the observed
    move, the threshold, and the offending bar's date — suitable for
    {!Weekly_snapshot.t.warnings} and the rendered report's warnings block. The
    line states that the candidate was {e flagged, not dropped}, so a reader
    does not go looking for a missing row. *)
