(** Adapter: live weekly-picks snapshots → {!Screen_record.t}.

    The decision-audit faithfulness lens ({!Screen_record}, {!Report},
    {!Counterfactual}) was built to consume a backtest's [trade_audit.sexp].
    This adapter lets the {b same} Phase-1 report and Phase-2 counterfactual run
    on {b live} weekly picks — the per-Friday {!Weekly_snapshot.t} screens
    written under [dev/weekly-picks/]. Additive and read-only: it produces
    {!Screen_record.t} values identical in shape to the backtest path, so no
    downstream code changes.

    {1 The funded / near-miss mapping}

    A live snapshot has no portfolio / cash line — it is a ranked candidate
    list, not a set of executed trades. We synthesize the funded/near-miss split
    from the {b displayed cut}: the top [displayed_k] long candidates (the picks
    a human would act on that week) stand in for the {b funded} entries, and
    everything below the cut — the remaining long candidates {b plus} all short
    candidates — becomes the {b near-misses}, tagged
    [Backtest.Trade_audit.Top_n_cutoff]. This is the live analog of the
    backtest's cash-rejected near-miss line: "what scored at this screen but sat
    below the line we displayed".

    {1 Assumptions and ceilings (documented, not silently defaulted)}

    - {b Stage.} A live {!Weekly_snapshot.candidate} does not carry its
      Weinstein stage. Long picks are Stage-2 breakouts by the screener's
      construction (buy only in Stage 2), so long candidates default to
      [Weinstein_types.Stage2 { weeks_advancing = 0; late = false }] with the
      record's [weeks_advancing] field left [None] (the count is not recovered).
      Short picks are Stage-4 declines by the same faithful construction (short
      only in Stage 4), so they default to
      [Weinstein_types.Stage4 { weeks_declining = 0 }].
    - [weeks_advancing] and [volume_ratio] are [None] — neither is carried in
      the snapshot schema. The RS / score / grade / sector comparison is what
      this adapter enables; the volume and advancing-weeks columns of the
      faithfulness table will therefore be empty for weekly-picks input.
    - [score] is [Float.iround_nearest_exn] of the snapshot's float score (the
      snapshot widened the screener's int score to float; we narrow it back). *)

val of_weekly_snapshots :
  Weinstein_snapshot.Weekly_snapshot.t list ->
  displayed_k:int ->
  Screen_record.t list
(** [of_weekly_snapshots snaps ~displayed_k] maps each weekly snapshot to one
    {!Screen_record.t}, sorted by screen date ascending.

    For each snapshot: [screen_date] is the snapshot [date]; [funded] is the
    first [displayed_k] [long_candidates] (already score-descending) mapped to
    {!Screen_record.funded_entry}; [near_misses] is the remaining long
    candidates (beyond the cut) unioned with all [short_candidates], each mapped
    to {!Screen_record.near_miss} with [reason_skipped = Top_n_cutoff] and the
    side that the source list implies ([Long] for the long overflow, [Short] for
    the short candidates); [summary] is computed via
    {!Screen_record.summary_of}.

    [displayed_k] must be non-negative; a value at or above a snapshot's long
    count funds every long candidate and leaves the long near-miss set empty.
    Raises [Invalid_argument] on a grade string the parser does not recognize —
    it never silently defaults an unknown label. *)
