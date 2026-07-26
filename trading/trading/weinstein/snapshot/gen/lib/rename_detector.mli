(** Live ticker-rename (succession) detection from price series alone — issue
    #2083 Finding 2.

    {1 What this closes}

    An engineering data-hygiene mechanism, {b not} a Weinstein book rule. No
    section of [docs/design/weinstein-book-reference.md] is cited because none
    supports it, and the Weinstein spine is untouched: stage classification, the
    Stage-2-only buy rule, volume confirmation, macro / sector gating, entry,
    stop and sizing all behave exactly as before. This module only decides
    whether a ticker's price series is still {e that company's} series.

    2026-07-17 incident (issue #2083): the weekly report's rank-1 pick "SNSE"
    did not exist at the broker — Sensei Biotherapeutics had renamed to Faeth
    Therapeutics (SNSE -> FTH) on 2026-06-16. Three failures compounded; the
    other two already have backstops on main ({!Sparse_tail_gate}, #2090, drops
    a candidate whose recent tail is too sparse to trust; {!Spike_bar_gate},
    #2097, flags a candidate whose signal rests on one outsized bar). Both are
    {e symptom} gates. This module is the only one that attacks the root cause:
    knowing the rename happened, and naming the successor ticker.

    {1 Succession, not concurrency}

    {!Twin_detector} (the snapshot-warehouse builder's detector) already scores
    returns-basis similarity between two series, and this module
    {b reuses that scoring primitive rather than reimplementing it} — see
    {!detect}. But [Twin_detector] answers a different question: "which series
    in this set are near-duplicates of each other, {e concurrently}?" It unions
    every matching pair into a group and keeps the latest-ending leg, so a dual
    listing or a duplicated vendor feed is reported the same way a rename is.

    A rename is a {b succession}, which is strictly more specific:

    - the predecessor is dense up to a changeover date [D] and then goes sparse
      or silent (the "zombie feed" — the vendor keeps emitting occasional stale
      prints under the dead symbol),
    - the successor has no history before [D] and becomes dense after it,
    - over whatever window the two {e do} overlap, their daily {b returns} match
      closely.

    Two fully-overlapping series that both stay dense are a concurrent twin, not
    a rename, and are {b not} reported here.

    {1 Why returns, not levels}

    The two legs of a rename usually carry different split/dividend adjustment
    bases, so their {e levels} diverge by a constant or drifting ratio while
    their daily returns stay near-identical. {!Twin_detector}'s own calibration
    on the real top-3000 warehouse records this: a levels comparison found 15
    exact-feed duplicate groups yet missed 9 of the 10 known rename twins
    (BLL/BALL, BKR/BHI, TXNM/PNM, ...), all of which score 0.95-0.99 on the
    returns basis, while genuine different-company controls (BALL/TAP,
    ASB_old/CDX_old) score below 0.06. {!Config.default} inherits that
    threshold.

    {1 Purity}

    [detect] is a pure function of {!Config.t}, [as_of] and a list of {!series}:
    no filesystem, no bar loading, no {!Weinstein_strategy.Bar_reader} — the
    caller owns loading, exactly as {!Twin_detector} does. The trading-day
    calendar used by the tail-density test is derived from the input itself (the
    sorted union of every date appearing in any input series), which over a
    whole universe {e is} the trading calendar.

    {b Consequence:} the input must contain enough densely-traded symbols to
    span the calendar. Handed two sparse series and nothing else, the union has
    holes, the trailing window covers more wall-clock time than it should, and
    both legs look denser than they are. Callers pass a whole universe, where
    this is a non-issue; tests that exercise two sparse legs must include a
    dense one.

    {1 Default-off}

    {!Config.default} has [enabled = false] and {!detect} then returns an empty
    report without inspecting the series at all. {!Weekly_snapshot_generator}
    builds its config via {!Config.armed} from
    [config.rename_detect_min_overlap_days] and
    [config.rename_detect_match_fraction], both of which default to the
    disabling value, so an unarmed run is bit-identical to pre-#2083-F2
    behaviour.

    {1 Known coverage limit}

    A rename is only visible when {b both} legs are present in the series list
    the caller passes. In the 2026-07-17 incident FTH was absent from the bar
    store entirely, so a run over that week's pinned universe would {e not} have
    caught SNSE -> FTH. Full coverage requires scanning the whole bar store (and
    then re-pinning the universe), which is a maintainer-local task outside this
    module's contract. Treat this as one layer of defence, not a guarantee.

    Two further blind spots follow from the handover criterion:

    - A rename whose changeover is only a few days before [as_of] leaves the
      successor with too few bars to clear [Config.min_successor_tail_density];
      it becomes detectable a couple of weeks later.
    - A clean cut-over with {b zero} overlap (the predecessor's last bar
      strictly precedes the successor's first) carries no shared dates, so there
      is nothing to score. Only a vendor symbol-change feed catches that case.
*)

open Core

module Config : sig
  type t = {
    enabled : bool;
        (** Master switch. [false] (the default) makes {!detect} an exact no-op
            — an empty report, no series inspected. *)
    min_overlap_days : int;
        (** Minimum number of dates the two legs must share before their returns
            are scored. A value below [2] disables detection entirely: a return
            needs two shared dates, so a 1-day overlap carries no returns
            evidence at all. Guards against a coincidental brush being called a
            rename.

            Note the returns compared are {e shared-date to shared-date}, not
            necessarily consecutive calendar days — a predecessor that has gone
            sparse still yields comparable multi-day returns, which is what
            makes a zombie tail scorable. *)
    match_fraction : float;
        (** A succession requires strictly more than this fraction of the
            overlap's consecutive-date return pairs to be near-identical.
            Default [0.95], the value {!Twin_detector.Config.default} uses and
            the one its top-3000 calibration validated. *)
    ret_epsilon : float;
        (** Tolerance for "near-identical" on one return pair: simple daily
            returns [ra] and [rb] match when [|ra - rb| <= ret_epsilon]. Default
            [1e-3], matching {!Twin_detector.Config.default}. *)
    min_predecessor_bars : int;
        (** The predecessor must have at least this many bars strictly before
            the changeover date. A ticker with almost no history behind it is
            not a company that got renamed. *)
    tail_window_trading_days : int;
        (** Width, in trading days drawn from the input's own date union, of the
            trailing window ending at [as_of] over which the handover is
            measured. *)
    max_predecessor_tail_density : float;
        (** The predecessor's bar count over [tail_window_trading_days], divided
            by that window, must be at most this. This is the "went sparse /
            silent" half of the handover signature — the half that distinguishes
            a succession from a concurrent twin. *)
    min_successor_tail_density : float;
        (** The successor's bar density over the same window must be at least
            this. The "took over" half of the handover signature. *)
  }
  [@@deriving sexp, eq]

  val default : t
  (** Disabled, with [min_overlap_days = 5], [match_fraction = 0.95],
      [ret_epsilon = 1e-3], [min_predecessor_bars = 60],
      [tail_window_trading_days = 15], [max_predecessor_tail_density = 0.5],
      [min_successor_tail_density = 0.8].

      [match_fraction] and [ret_epsilon] are {!Twin_detector.Config.default}'s,
      so the two detectors agree on what "the same series" means. The remaining
      values are sized to the 2026-07-17 incident shape: the sparse-tail gate is
      armed at a 15-trading-day window in
      [dev/weekly-picks/live-config-overrides.sexp], over which the zombie SNSE
      feed carried 6 bars (density 0.4, under [0.5]) while a live successor
      carries essentially every bar (density 1.0, over [0.8]). *)

  val armed : min_overlap_days:int -> match_fraction:float -> t
  (** [armed ~min_overlap_days ~match_fraction] is {!default} with those two
      knobs applied and [enabled] set to
      [min_overlap_days > 0 && match_fraction > 0.0]. Either knob at its
      disabling value ([0] / [0.0], which are the strategy-config defaults)
      yields a disabled config, so arming is explicit and requires both. *)
end

type series = {
  symbol : string;
  closes : (Date.t * float) array;
      (** Adjusted closes, {b sorted ascending by date}, one entry per trading
          day the symbol has a bar for. Entries after [as_of] are ignored. *)
}
[@@deriving sexp_of]

type rename = {
  old_symbol : string;  (** The predecessor — the ticker that went stale. *)
  new_symbol : string;  (** The successor — the ticker that took over. *)
  changeover : Date.t;
      (** The successor's first bar date; the estimated effective date of the
          rename. *)
  overlap_days : int;  (** Dates the two legs share. *)
  match_fraction : float;
      (** Fraction of the overlap's consecutive-date return pairs that matched
          within [Config.ret_epsilon]. *)
  old_tail_bars : int;
      (** Predecessor bars in the trailing [tail_window_trading_days]. *)
  new_tail_bars : int;  (** Successor bars in the same window. *)
  tail_window_trading_days : int;
      (** Actual window width used — the configured value, or fewer when the
          input does not span that many trading days. *)
}
[@@deriving sexp_of, eq]

type report = {
  config : Config.t;
  renames : rename list;
      (** Detected successions, sorted ascending by [old_symbol]. Each
          predecessor appears at most once: when several successors qualify, the
          highest [match_fraction] wins (ties broken by the smaller
          [new_symbol]) so the mapping is a function. *)
}
[@@deriving sexp_of]

val detect : Config.t -> as_of:Date.t -> series list -> report
(** [detect config ~as_of series] finds ticker successions among [series],
    considering only bars dated at or before [as_of].

    Returns an empty report immediately when [config.enabled] is [false] — the
    series are not inspected.

    An ordered pair [(old, new)] is reported when all of the following hold,
    where [D] is [new]'s first bar date:

    - [D] is strictly after [old]'s first bar date and at or before [old]'s last
      bar date — the successor is the younger leg and the two actually overlap;
    - [old] has at least [config.min_predecessor_bars] bars strictly before [D],
      and [new] has none (true by construction of [D]) — the old ticker carried
      the history, the new one starts at the changeover;
    - over the trailing [config.tail_window_trading_days] trading days ending at
      [as_of], [old]'s bar density is at most
      [config.max_predecessor_tail_density] and [new]'s is at least
      [config.min_successor_tail_density] — the handover signature that
      separates a succession from a concurrent twin;
    - the legs share at least [config.min_overlap_days] dates and more than
      [config.match_fraction] of the overlap's consecutive-date return pairs
      agree within [config.ret_epsilon].

    {b Direction.} Which leg is the predecessor is decided by the tail-density
    pair, not by whose last bar is later: a zombie feed can print on the very
    last session and still be the dead leg. Because the two density tests point
    opposite ways, at most one ordering of a pair can qualify.

    {b Scoring reuse.} The last criterion is evaluated by calling
    {!Twin_detector.detect} on the two-series pair with [basis = Returns],
    [min_overlap_days = 2] (which makes its anchor stride [1], so its prefilter
    is exhaustive over the pair and cannot drop a genuine match) and this
    module's [match_fraction] / [ret_epsilon]; the resulting [pair_match]
    supplies [overlap_days] and [match_fraction]. No similarity arithmetic is
    duplicated here.

    Pure: same inputs -> same output, in a deterministic order. *)

val mapping : report -> (string * string) list
(** [mapping report] is the [(old_symbol, new_symbol)] pairs, in [report]'s
    order. This is the artefact a universe re-pin would consume: "wherever the
    universe says [old], it now means [new]". Empty for a disabled-config
    report. *)

val survivors : report -> all_symbols:string list -> string list
(** [survivors report ~all_symbols] is [all_symbols] with every detected
    predecessor removed, preserving the input order. A successor already present
    in [all_symbols] is kept — the two halves are asserted separately. With a
    disabled-config (empty) report this is [all_symbols] unchanged: the
    bit-identical passthrough. *)

val warnings : report -> string list
(** [warnings report] is one human-readable line per detected succession, naming
    the predecessor, the successor, the changeover date, the overlap and the
    match score — suitable for {!Weekly_snapshot.t.warnings} and the rendered
    report, so a dropped pick is visible and carries the ticker a trader should
    look at instead. Empty for a disabled-config report. *)

val render : report -> string
(** [render report] formats the config and every detected succession as
    human-readable multi-line text, for a CLI summary or a sidecar report file.
*)
