open Types

(** Decline-character classifier — a pure, lookahead-free read-only signal that
    labels the {b current} character of a market decline.

    This is the shared primitive of the decline-character build sequence
    (dev/notes/decline-character-exploration-2026-06-21-PM.md). Two later
    consumers read it:
    - {b slow-grind → faithful short}: a sustained distribution bear is the
      regime Weinstein sanctions shorting into (book Ch. 8, 11).
    - {b fast-V → tight absolute long stop}: a fast crash is the tail-RISK the
      structural MA/correction-low trailing stop misses (it trails a distant
      correction low and re-checks only weekly, so longs exit at the bottom —
      the 2020 problem). Arming a tight absolute stop only on [Fast_v] keeps it
      dormant in normal bull chop, so it does not tax the let-winners-run fat
      tail (the sanctioned tail-RISK-insurance exception).

    {b Faithfulness}: this encodes Weinstein's Advance-Decline-lead breadth
    doctrine (book Ch. 8 — in a genuine distribution top the A/D line peaks and
    rolls over while the index is still near its highs; a fast V-crash gives no
    such breadth lead) as a read-only dial, not a spine change. It buys/sells
    nothing on its own — it changes no behaviour until a consumer reads it.

    {b Lookahead-free}: every input is computed from the [Macro.result] for the
    current week plus index bars at the current week or earlier. No future bar
    is ever read.

    All functions are pure: same inputs always produce the same output. *)

type t =
  | Slow_grind
      (** A sustained distribution decline: the A-D line is {b leading} the
          index lower (breadth bearish while price has not yet broken far from
          its high), OR the index has spent many consecutive weeks below a
          falling MA at a shallow rate. The faithful-short regime. *)
  | Fast_v
      (** A fast V-shaped crash: breadth is {b not} leading (the A-D line
          collapses with the index, no lead) and the index falls steeply over a
          short window. The tight-absolute-stop regime. *)
  | Not_declining
      (** The tape is not in a decline (e.g. the MA is rising, or the current
          close is not below a falling MA). Neither consumer arms. *)
[@@deriving show, eq, sexp]

type config = {
  ad_lead_max_drawdown_pct : float;
      (** How far below its trailing high the index may be and still count the
          A-D line as {b leading} it (breadth bearish before price has broken
          down). A drawdown shallower than this with a bearish A-D line is the
          distribution-lead signature. Default: 0.10 (within 10% of the high).
      *)
  rate_lookback_weeks : int;
      (** Trailing window (weeks) over which the rate-of-decline drawdown is
          measured: [(close_lookback - close_now) / close_lookback]. Default: 4.
      *)
  slow_grind_max_rate_pct : float;
      (** Upper bound on the per-window {b drawdown} magnitude (positive
          fraction, e.g. 0.04 = 4% over the window) for the decline to count as
          a shallow grind on the weeks-below-MA leg. Default: 0.04. *)
  fast_v_min_rate_pct : float;
      (** Lower bound on the per-window drawdown magnitude (positive fraction)
          for the decline to count as a steep fast-V crash. Default: 0.08. *)
  weeks_below_ma_slow_grind : int;
      (** Minimum consecutive weeks the index close has been below a {b falling}
          MA to call a shallow decline a slow grind. Default: 8. *)
  trailing_high_lookback_weeks : int;
      (** Window (weeks) over which the trailing index high is taken for the
          A-D-lead drawdown comparison. Default: 52 (~1 year). *)
  fast_v_ignores_ma_filter : bool; [@sexp.default false]
      (** {b Arming-speed dial} for the fast-V path (default [false] = exactly
          today's behaviour). When [false], {!classify} returns [Not_declining]
          for any tape that is not already in a decline by the MA test (MA
          Rising/Flat, or the close not yet below a falling MA) — so the fast-V
          path cannot arm until the weekly MA has rolled over and price has
          fallen below it. In a fast V-crash that confirmation lags the crash by
          weeks (the 2020 problem: the MA does not roll over until ~mid-March,
          after the gap-down has already exited every long), so the
          [Fast_v]-gated absolute stop never gets a chance to fire.

          When [true], the fast-V-on-rate path is evaluated even when no decline
          is in progress by the MA test: if the trailing rate-of-decline
          drawdown over [rate_lookback_weeks] exceeds [fast_v_min_rate_pct] (and
          the A-D line is not leading), {!classify} returns [Fast_v] on rate
          alone — dropping the falling-MA precondition for the fast-V path only.
          The slow-grind path is {b never} reached this way: a slow grind
          legitimately requires weeks-below-a-falling-MA, which presupposes a
          decline already in progress.

          {b Faithfulness}: a fast crash gives no Advance-Decline breadth lead
          and falls steeply before the weekly MA can roll over (book Ch. 8
          distribution-lead doctrine — the MA confirmation is built for the slow
          distribution top, not the V-crash). Arming the tail-RISK-insurance
          absolute stop on rate captures the gap-down the weekly-MA confirmation
          structurally misses. This changes no buy/sell rule — only {b when} the
          [Fast_v]-gated absolute stop arms — so it is the sanctioned
          tail-RISK-insurance exception ([weinstein-faithful-core.md]), not a
          spine change. *)
}
[@@deriving show, eq, sexp]
(** Tunable thresholds for {!classify}. Every threshold is a config field (no
    hardcoded magic numbers) so the signal is gridable as a [Variant_matrix]
    axis once a consumer wires it. Defaults reflect the illustrative thresholds
    in the exploration note: weeks-below-MA ≥ 8, drawdown < 4%/window = shallow,
    > 8%/window = steep, A-D-lead while index within ~10% of its high. *)

val default_config : config
(** [default_config] returns the exploration-note reference thresholds. *)

val classify :
  config:config -> macro:Macro.result -> index_bars:Daily_price.t list -> t
(** [classify ~config ~macro ~index_bars] labels the current decline character.

    @param macro
      The already-computed macro result for the current week. Its
      [index_stage.ma_value] / [index_stage.ma_direction] give the MA level and
      slope, and its [indicators] list carries the "A-D Line" reading whose
      [`Bearish] / [`Bullish] / [`Neutral] signal drives the A/D-lead leg. A
      missing or [`Neutral] A-D reading means "no breadth lead" (treated as not
      leading) — faithful to the current [~ad_bars:[]] wiring where the
      indicator is [`Neutral] until breadth data lands (Build 0).
    @param index_bars
      Weekly bars for the primary index, chronological oldest-first. Read at the
      current week (last bar) and earlier offsets only — never the future. Used
      to compute the rate-of-decline drawdown, the trailing-high drawdown, and
      the weeks-below-falling-MA count.

    Classification rule (thresholds from [config]):
    - When no decline is in progress (the MA is rising/flat, or the current
      close is not below a falling MA): {!Not_declining}, {b unless}
      [fast_v_ignores_ma_filter = true] — in which case the fast-V-on-rate path
      is still evaluated and returns {!Fast_v} when the A-D line is not leading
      AND the drawdown magnitude over [rate_lookback_weeks] >
      [fast_v_min_rate_pct] (else {!Not_declining}). The slow-grind path is
      never taken on this branch (a slow grind presupposes a decline in
      progress).
    - When a decline is in progress: {!Slow_grind} when the A-D line is leading
      (A-D [`Bearish] while the index is still within [ad_lead_max_drawdown_pct]
      of its trailing high), OR (weeks-below-falling-MA ≥
      [weeks_below_ma_slow_grind] AND the drawdown magnitude over
      [rate_lookback_weeks] < [slow_grind_max_rate_pct]).
    - {!Fast_v} when the A-D line is not leading AND the drawdown magnitude over
      [rate_lookback_weeks] > [fast_v_min_rate_pct].
    - {!Not_declining} otherwise (an ambiguous shallow dip with no qualifying
      grind or crash signal).

    Pure and lookahead-free. *)
