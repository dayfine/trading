(** Stub-print tail guard (issue #2672, guard 3 of 3).

    Truncates the {b terminal} run of implausible penny prints that a delisted
    symbol's warehouse series carries after its last real bar, so neither the
    simulator nor the strategy can trade against them.

    {2 The defect}

    Measured case (#2672): {b STMP}'s series has real bars through 2021-10-04 at
    $329.61, then $0.045 / $0.04 / $0.03 prints to the end of the series. A held
    long's stop sits far above $0.045, so [Weinstein_stops.check_stop_hit] sees
    [low <= stop] on the first stub bar, emits a Market sell, and
    [Fill_rules.would_fill_market] fills it at that bar's open — a −$594k
    phantom loss in the canonical 26-year record, present in 56 of 92 committed
    trade sets. The bar survives every existing filter:
    [Market_data_adapter._is_valid_bar] rejects only [close <= 0], and $0.03 is
    positive.

    {2 What is and is not truncated}

    A bar is a {b stub} relative to a reference close [r] when
    [close < ratio *. r]. This module removes the longest run of stubs that
    {b extends to the end of the series}, measured against the close of the last
    bar before that run. Concretely: it keeps the largest prefix
    [bars[0 .. k-1]] such that every bar in [bars[k .. n-1]] is a stub relative
    to [bars[k-1]].

    - {b STMP shape} — [329.61] then [0.045 / 0.04 / 0.03] to the end: truncated
      immediately after [329.61].
    - {b CLE shape} — months of interleaved ~$0.70 / ~$0.03 prints, final bar
      [0.025] after [0.68]: only the final bar is dropped. The run cannot extend
      backwards past the [0.68], because [0.68] is not a stub relative to the
      ~$0.70 before it.
    - {b A real crash} — [100.0] to [40.0] followed by more bars near [40.0]:
      untouched at any sane ratio, because the run's own maximum is nowhere near
      [ratio] of the pre-crash close.

    This is {b data hygiene with lookahead}, and deliberately so: whether a run
    of prints is terminal is only knowable from the whole series. It is {b not}
    a crash detector — a mid-series collapse that later recovers is left
    entirely alone, so the strategy still sees (and can still lose money on)
    every decline that keeps printing.

    {2 The known cost: terminal collapses are indistinguishable from stubs}

    The rule keys on price shape alone, so it {b cannot} tell an administrative
    stub tail from a {b genuine terminal collapse}. A symbol that really traded
    down through the ratio and was then delisted presents to {!cutoff_date} as
    exactly the same shape and is truncated too — deleting a real loss and
    biasing returns {b upward}. Only the {e gradual} terminal decline survives,
    because each of its steps stays above the ratio:

    - [10.0 / 5.0 / 1.0 / 0.30 / 0.28] at [ratio = 0.05] —
      {b nothing truncated}. No suffix is below [0.05] of the close before it.
    - [10.0 / 9.0 / 0.20 / 0.15] at [ratio = 0.05] —
      {b truncated after the 9.0}, identically to the STMP stub tail, even
      though a real bankruptcy of that shape is a −98% loss the run should have
      taken.

    So the narrower true claim is: the bars this rule removes {e include} ones
    no counterparty could have filled against, but are not limited to them. That
    upward bias is an accepted cost of a {b default-off} axis and must be
    carried into the paired re-run writeup — it is not a property to rely on,
    and not a reason to flip the default. Both shapes are pinned in
    [test_stub_tail.ml].

    {2 Where it applies}

    The two readers over a snapshot warehouse must agree, or the simulator would
    fill against a bar the strategy cannot see. {!wrap_callbacks} covers the
    strategy side ({!Snapshot_bar_views} reads every daily / weekly view through
    {!Snapshot_callbacks.read_field_history}), and the same {!t} is handed to
    the simulator's bar source, so both resolve one memoized cutoff per symbol.

    {b Default [ratio = 0.0] = off}, bit-identical to every existing
    baseline/golden, and the short-circuit keeps the per-symbol close scan off
    the default path entirely (R1). Axis-expressible as
    [((flag stub_print_max_ratio) (values (0.0 0.02 0.05 0.1)))]. See
    [Weinstein_strategy_config.stub_print_max_ratio]. *)

open Core

(** {1 Pure truncation} *)

val cutoff_date : ratio:float -> (Date.t * float) list -> Date.t option
(** [cutoff_date ~ratio closes] is the date of the last {b real} bar in the
    chronologically-ordered [closes] series — i.e. the series should be
    truncated to dates [<= that]. [None] means "keep everything".

    Returns [None] when [ratio <= 0.0] (off), when the series has fewer than two
    usable bars, or when no terminal stub run exists. Entries whose close is
    [Float.nan] are ignored (the schema's "value unknown" sentinel), as are
    reference bars whose close is [<= 0.0]. Pure. *)

val truncate :
  ratio:float -> Types.Daily_price.t list -> Types.Daily_price.t list
(** [truncate ~ratio bars] drops the terminal stub run from a
    chronologically-ordered bar list, per {!cutoff_date} over the bars'
    [close_price] (the raw close — the basis the stop check and the fill both
    read). Identity when [ratio <= 0.0] or no stub run exists. Pure. *)

(** {1 Warehouse-backed resolver} *)

type t
(** A per-symbol cutoff resolver: the ratio plus a memo of each symbol's cutoff
    date, computed on first use from that symbol's full close series. Not
    thread-safe (same assumption as {!Daily_panels}). *)

val of_callbacks : ratio:float -> Snapshot_callbacks.t -> t
(** [of_callbacks ~ratio cb] builds a resolver that reads each symbol's close
    series through [cb] on first use. [ratio <= 0.0] produces a resolver that is
    never armed and never reads. *)

val is_armed : t -> bool
(** [is_armed t] is [false] for a [ratio <= 0.0] resolver — the caller's
    short-circuit, so an unarmed guard costs nothing per read. *)

val cutoff_for : t -> symbol:string -> Date.t option
(** [cutoff_for t ~symbol] is [symbol]'s truncation cutoff (inclusive last real
    bar), memoized. [None] when unarmed, when the symbol is unknown, or when the
    symbol has no terminal stub run. *)

val keeps : t -> symbol:string -> date:Date.t -> bool
(** [keeps t ~symbol ~date] is [false] iff [date] falls strictly after
    [symbol]'s cutoff — i.e. the bar is part of the truncated stub tail. Always
    [true] for an unarmed resolver. *)

val clamp_until : t -> symbol:string -> until:Date.t -> Date.t
(** [clamp_until t ~symbol ~until] is [until] capped at [symbol]'s cutoff, for
    callers that read a date range. Returns [until] unchanged for an unarmed
    resolver or a symbol with no cutoff. *)

val wrap_callbacks : t -> Snapshot_callbacks.t -> Snapshot_callbacks.t
(** [wrap_callbacks t cb] returns [cb] with its two read closures filtered by
    [t]: [read_field] on a truncated date answers [Error NotFound] (the same
    error an absent row produces, which {!Snapshot_bar_views} already folds to
    the empty view), and [read_field_history] has its [until] clamped via
    {!clamp_until}. Returns [cb] itself, physically unchanged, when [t] is
    unarmed.

    [active_through_for] is passed through {b unchanged}: stamping the cutoff
    onto it would arm the screener's point-in-time filter as a side effect,
    which is a different mechanism with its own flag
    ([Weinstein_strategy_config.enable_pi_filter]) and is not what this guard
    claims to do. *)
