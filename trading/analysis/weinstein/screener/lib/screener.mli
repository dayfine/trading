(** Weinstein cascade screener.

    Applies a three-level filter (macro → sector → stock) and returns ranked
    buy/short candidates with grades and suggested entry/stop.

    Cascade rules (from design doc): 1. MACRO GATE: Bearish market → no new
    buys. Bullish market → no new shorts (except A+ setups). Neutral → both
    active. 2. SECTOR FILTER: Stock in a Weak sector → excluded from buys. Stock
    in a Strong sector → excluded from shorts. 3. SCORING: Additive weighted
    score from config weights. 4. FILTER + SORT: Remove below min_grade. Remove
    already-held tickers. Sort by score descending.

    All functions are pure. *)

include module type of Screener_scoring
(** Scoring types, signal functions, and price utilities — re-exported from
    {!Screener_scoring} so callers can use [Screener.sector_rating],
    [Screener.scoring_weights], etc. without importing the sub-module directly.
*)

type candidate_params = {
  entry_buffer_pct : float;
      (** Fraction above breakout price for the suggested entry. Default: 0.005.
      *)
  initial_stop_pct : float;
      (** Fraction below entry for the screener's {b advisory} long initial
          stop. Default: 0.08.

          Feeds {!scored_candidate.suggested_stop} and
          {!scored_candidate.risk_pct} only — does not drive the installed stop
          in the trade-execution path (the G15 refactor severed that coupling;
          see [entry_audit_capture.ml] §"G15 step 3"). To widen the installed
          stop, use {!installed_stop_min_pct} instead. *)
  short_stop_pct : float;
      (** Fraction above entry for the short initial stop. Default: 0.08. *)
  base_low_proxy_pct : float;
      (** Fraction below MA used as proxy for the prior base low. Default: 0.15.
      *)
  breakout_fallback_pct : float;
      (** Fraction above MA used as breakout price when none is detected.
          Default: 0.05. *)
  installed_stop_min_pct : float;
      (** Floor on the installed-stop distance from entry. Default: 0.0 (no
          floor — the standard support-floor / fallback-buffer logic decides the
          stop unmodified).

          When set to a positive fraction, the strategy plumbs this through to
          {!Weinstein_stops.widen_initial_to_min_distance}, so the [Initial]
          stop is widened (if necessary) to sit at least
          [installed_stop_min_pct] away from entry. A support-floor-derived stop
          that already sits at least that far is preserved.

          Use-case: entry-caps-style sweeps that want to test wider stops (e.g.
          arm C of the 2026-05-12 entry-caps experiment intended to set this to
          0.10 but inadvertently set the advisory {!initial_stop_pct} instead —
          that field was severed from the installed-stop path by the G15
          refactor). Restores the original "screener-set fraction drives the
          installed stop" intent without shifting the default-config goldens.

          Opt-in semantics: the field is [[\@sexp.default 0.0]] so an overlay
          sexp that omits the field deserialises to [0.0] (no widening). *)
}
[@@deriving sexp]
(** Per-candidate price computation parameters. All configurable. *)

val default_candidate_params : candidate_params
(** [default_candidate_params] provides the reference parameters. *)

type volume_ratio_band = { low : float; high : float } [@@deriving sexp]
(** Half-open volume-ratio exclusion band used by
    {!config.volume_ratio_exclude_range}. The named-field record (rather than a
    plain [float * float] tuple) keeps the on-disk sexp shape outside the
    runner's deep-merge "looks like a record" heuristic, so a partial-config
    overlay that sets just this field deep-merges correctly. *)

type config = {
  weights : scoring_weights;
  grade_thresholds : grade_thresholds;
      (** Score cutoffs for each grade. Default: [default_grade_thresholds]. *)
  candidate_params : candidate_params;
      (** Per-candidate price parameters. Default: [default_candidate_params].
      *)
  min_grade : Weinstein_types.grade;
      (** Minimum grade to include in output. Default: C. Used unless
          [min_score_override] is [Some _] — in that case the numeric override
          takes precedence and the grade ladder is bypassed. *)
  min_score_override : int option; [@sexp.default None]
      (** Optional numeric score floor that, when [Some n], replaces the
          {!min_grade} filter with a strict [score >= n] gate on the cascade
          output. The numeric form is the natural tuning knob — sweepers can
          vary a single integer (e.g. 38..50) without having to also adjust the
          grade ladder ordering implied by {!grade_thresholds}.

          Default: [None] — preserves the {!min_grade} grade-based filter
          bit-equally. The grade label on each surviving candidate is still
          computed from {!grade_thresholds} regardless.

          Authority: GitHub issue #888 — "expose threshold as a config
          parameter; add to the M5.5 grid_search sweep parameter list". The
          design intent is to make the cascade score gate a single tunable
          dimension. *)
  max_score_override : int option; [@sexp.default None]
      (** Optional numeric score ceiling. When [Some n], candidates with
          [score >= n] are rejected from the cascade output. Composes with
          {!min_score_override}: a candidate survives only if [low <= score < n]
          where [low] is whichever floor is in effect.

          Default: [None] — no ceiling.

          Motivation: per-quintile entry-feature analysis on rolling 5y Cell E
          trades (dev/notes/entry-signal-quintiles-2026-05-11.md) showed the top
          score quintile (≥80) has 28.6% win rate (worst of all buckets) and ≈
          $0 average P&L per trade — the screener's highest-confidence
          candidates produce no edge. Capping at 79 or 80 lets the cascade fall
          through to the next-best candidates from the still-abundant pool (avg
          12.5 admitted per Friday vs ~1.3 entered).

          The cap is applied at the same gate as {!min_score_override} so the
          cascade-diagnostics phase counters stay consistent. *)
  volume_ratio_exclude_range : volume_ratio_band option; [@sexp.default None]
      (** Optional half-open exclusion band on the candidate's
          [volume.volume_ratio] (event-volume / avg-volume). When
          [Some {low; high}], a candidate is rejected if its volume ratio falls
          in the half-open interval from [low] (inclusive) to [high]
          (exclusive). Composes with the score gates: a candidate survives only
          if both the score is in band and the volume ratio is not in the
          excluded band.

          Default: [None] — no exclusion.

          Motivation: per-quintile entry-feature analysis on rolling 5y Cell E
          trades (dev/notes/entry-signal-quintiles-2026-05-11.md) showed the
          volume_ratio bucket between 2.5 and 3.0 is the only negative-$/trade
          bucket and second-worst on win rate. Extreme volume (3.0 and above)
          recovers on $/trade despite lower WR (fat-tail bull setups), so the
          right cap is "exclude 2.5 to 3.0", not "exclude everything above 2.5".
          This knob exposes the band as a single tunable so sweepers can move
          the boundaries without code edits.

          Candidates with no [volume] result (e.g. insufficient bars to compute
          the ratio) are admitted unconditionally — the gate is only a filter
          when the ratio is computable. The cascade-diagnostics phase counters
          treat exclusion as part of the breakout phase (no new counter is
          added; the candidate is simply absent from the downstream phases). *)
  max_buy_candidates : int;
      (** Maximum number of buy candidates returned. Default: 20. *)
  max_short_candidates : int;
      (** Maximum number of short candidates returned. Default: 10. *)
  cascade_post_stop_cooldown_weeks : int; [@sexp.default 0]
      (** Per-symbol post-stop-out cooldown, in weeks. After a position stops
          out, the symbol is excluded from the cascade for this many weeks.
          Default: [0] (disabled — preserves prior behaviour bit-equally). When
          [> 0], callers must pass [~as_of] and [~last_stop_out_dates] to
          {!screen}; otherwise the gate is a no-op (no map → no exclusion).

          Authority: weinstein-book-reference.md §Buy-Side Rules implies a
          stopped-out trade signals the breakout was false. The book does not
          prescribe a specific cooldown, so this lever is configurable. Surfaced
          in response to the same-week re-fire pattern documented in
          dev/notes/sp500-trade-quality-findings-2026-04-30.md §"Cascade
          re-firing within days of stop-out". *)
}
[@@deriving sexp]
(** Main screener configuration. *)

val default_config : config
(** [default_config] returns recommended defaults. *)

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  side : Trading_base.Types.position_side;
      (** Which side this candidate is for — [Long] for buy candidates, [Short]
          for short candidates. Long candidates come from the buy-cascade path;
          short candidates from the short-cascade path. *)
  grade : Weinstein_types.grade;
  score : int;
  suggested_entry : float;
      (** Suggested buy-stop entry price (breakout_price + small buffer). *)
  suggested_stop : float;
      (** Suggested initial stop-loss. For longs, below the prior base low; for
          shorts, above the prior rally high. *)
  risk_pct : float;
      (** |suggested_entry - suggested_stop| / suggested_entry. *)
  swing_target : float option;
      (** Estimated swing target using Weinstein's swing rule, if computable. *)
  rationale : string list;
      (** Human-readable list of signals that contributed to this grade. *)
}
(** A scored and graded candidate ready for the weekly report. *)

type cascade_diagnostics = {
  total_stocks : int;
      (** Number of stocks input to {!screen} this run (post strategy-side phase
          1
          + sector pre-filter; pre held-ticker exclusion). *)
  candidates_after_held : int;
      (** [total_stocks] minus tickers in [held_tickers]. *)
  macro_trend : Weinstein_types.market_trend;
      (** The macro trend that gated this cascade — same value as
          [result.macro_trend]. Carried in the diagnostics record so consumers
          can read the regime without cross-referencing the parent {!result}. *)
  long_macro_admitted : int;
      (** [candidates_after_held] when [macro_trend <> Bearish], else [0]. The
          macro gate is binary across all candidates per side. *)
  long_breakout_admitted : int;
      (** Of [long_macro_admitted], how many satisfied
          [Stock_analysis.is_breakout_candidate]. *)
  long_sector_admitted : int;
      (** Of [long_breakout_admitted], how many sat in a sector that was not
          [Weak]. *)
  long_grade_admitted : int;
      (** Of [long_sector_admitted], how many scored at or above [min_grade]. *)
  long_top_n_admitted : int;
      (** [List.length buy_candidates] — survivors after the
          [max_buy_candidates] cap. *)
  short_macro_admitted : int;
      (** [candidates_after_held] when [macro_trend <> Bullish], else [0]. *)
  short_breakdown_admitted : int;
      (** Of [short_macro_admitted], how many satisfied
          [Stock_analysis.is_breakdown_candidate]. *)
  short_sector_admitted : int;
      (** Of [short_breakdown_admitted], how many sat in a sector that was not
          [Strong]. *)
  short_rs_hard_gate_admitted : int;
      (** Of [short_sector_admitted], how many were not blocked by the RS hard
          gate (Weinstein Ch. 11 — never short a stock with strong relative
          strength). *)
  short_grade_admitted : int;
      (** Of [short_rs_hard_gate_admitted], how many scored at or above
          [min_grade]. *)
  short_top_n_admitted : int;
      (** [List.length short_candidates] — survivors after the
          [max_short_candidates] cap. *)
}
[@@deriving sexp]
(** Per-cascade-phase admission counts for one {!screen} call.

    Captured pure-functionally — same input → same diagnostics. Pairs with the
    backtest-side per-Friday cascade-summary record so analyses can answer "how
    often did the macro gate filter everything" / "did the RS hard gate ever
    block shorts" without re-running the strategy. *)

type result = {
  buy_candidates : scored_candidate list;  (** Ranked by score descending. *)
  short_candidates : scored_candidate list;  (** Ranked by score descending. *)
  watchlist : (string * string) list;
      (** Tickers with grade C that passed the filter but missed top-N.
          [(ticker, reason)]. *)
  macro_trend : Weinstein_types.market_trend;
      (** The macro trend used by the cascade gate. *)
  cascade_diagnostics : cascade_diagnostics;
      (** Per-phase admission counts. Populated unconditionally — has zero cost
          when ignored, and unblocks per-Friday cascade-rejection tracking on
          the backtest side without requiring a parallel pass. *)
}
(** Screener output. *)

val screen :
  config:config ->
  macro_trend:Weinstein_types.market_trend ->
  sector_map:(string, sector_context) Core.Hashtbl.t ->
  stocks:Stock_analysis.t list ->
  held_tickers:string list ->
  result
(** [screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers] runs the
    cascade filter and returns ranked candidates.

    @param config Screener parameters.
    @param macro_trend Overall market trend from Macro analyzer.
    @param sector_map Map from ticker to sector context.
    @param stocks Per-stock analysis results.
    @param held_tickers Tickers already in portfolio — excluded from output.

    Pure function. Equivalent to {!screen_with_cooldown} with [as_of = None] and
    [last_stop_out_dates = []] — i.e. the post-stop-out cooldown gate is a no-op
    regardless of [config.cascade_post_stop_cooldown_weeks]. *)

val screen_with_cooldown :
  config:config ->
  macro_trend:Weinstein_types.market_trend ->
  sector_map:(string, sector_context) Core.Hashtbl.t ->
  stocks:Stock_analysis.t list ->
  held_tickers:string list ->
  as_of:Core.Date.t ->
  last_stop_out_dates:(string * Core.Date.t) list ->
  result
(** [screen_with_cooldown] is {!screen} with the per-symbol post-stop-out
    cooldown gate active.

    @param as_of Cascade evaluation date.
    @param last_stop_out_dates
      Per-symbol last stop-out date. Each entry [(ticker, date)] excludes
      [ticker] from the cascade if
      [(as_of - date) < config.cascade_post_stop_cooldown_weeks * 7] days. When
      [config.cascade_post_stop_cooldown_weeks = 0] the gate is a no-op, so this
      function is bit-equal to {!screen} on the same inputs.

    Authority: weinstein-book-reference.md §Buy-Side Rules — a stopped-out trade
    signals the breakout was false; book does not prescribe a specific cooldown
    so it is configurable.

    Pure function. *)
