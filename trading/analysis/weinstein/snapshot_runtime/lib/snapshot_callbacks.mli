(** Thin field-accessor shim over {!Daily_panels.t}.

    Phase C of the daily-snapshot streaming pipeline (see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase C). The
    plan calls for "strategy + screener consume via thin shim preserving
    existing callback APIs"; this module is the field-level half of that.

    {2 Why a shim, not a [Stock_analysis.callbacks] adapter}

    The existing {!Stock_analysis.callbacks} type expects bar-shaped accessors
    ([get_high ~week_offset], nested [Stage.callbacks] / [Rs.callbacks] /
    [Volume.callbacks] / [Resistance.callbacks] each of which itself takes
    [week_offset]) — a contract built around walking a bar history. The Phase C
    runtime stores precomputed scalars per (symbol, date), not bars; producing
    bar-shaped callbacks from snapshots would either require re-deriving bar
    tuples (defeats the point) or bridging the two shapes inside the shim (large
    code, Phase D scope).

    Phase C therefore exposes a smaller surface: one closure per field type that
    takes (symbol, date) and returns the precomputed scalar. Phase D is
    responsible for plugging this into whatever bar-shaped consumer the strategy
    ends up calling — by then the strategy hot path will read directly from
    snapshots and the bar-shaped layer can be retired (plan §Phase F).

    The shim is a record of closures so callers can pass it around without
    holding a reference to {!Daily_panels.t} directly. The closures retain a
    reference to the underlying cache, and reads go through
    {!Daily_panels.read_today} (LRU-promoting). *)

type t = {
  read_field :
    symbol:string ->
    date:Core.Date.t ->
    field:Data_panel_snapshot.Snapshot_schema.field ->
    float Status.status_or;
      (** [read_field ~symbol ~date ~field] returns the precomputed scalar for
          [field] in the snapshot at (symbol, date).

          - [Error NotFound] when (symbol, date) does not resolve to a row
          - [Error Failed_precondition] when the snapshot's schema does not
            contain [field] (caller asked for an indicator the manifest wasn't
            built with)
          - [Error Internal] for filesystem / decode errors. *)
  read_field_history :
    symbol:string ->
    from:Core.Date.t ->
    until:Core.Date.t ->
    field:Data_panel_snapshot.Snapshot_schema.field ->
    (Core.Date.t * float) list Status.status_or;
      (** [read_field_history ~symbol ~from ~until ~field] returns
          [(date, value)] pairs for [field] across the inclusive date range,
          ordered chronologically.

          A snapshot row whose [field] value is [Float.nan] is preserved in the
          result with [snd] = [Float.nan]; the caller decides what NaN means in
          context (e.g. ATR-14 on day < 14 of a symbol's history per the Phase B
          contract). *)
}
(** Field-level accessor bundle.

    The two closures fan out to the same {!Daily_panels.t}. They share LRU state
    — back-to-back reads on the same symbol are O(1). *)

val of_daily_panels : Daily_panels.t -> t
(** [of_daily_panels panels] builds a shim that reads from [panels].

    The returned closures hold a reference to [panels] and become invalid after
    [Daily_panels.close panels] in the sense that subsequent reads will reload
    from disk on demand. The shim does not own [panels]; the caller owns
    [panels]'s lifetime. *)
