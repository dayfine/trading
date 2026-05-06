(** Fixed-dollar all-eligible trade-grading diagnostic.

    For every Stage-2 entry signal that fires across a backtest period,
    allocates a fixed dollar amount (default $10K) per signal, bypasses every
    portfolio-level rejection (no cash floor, no exposure cap, no sector
    concentration), tracks each position independently to its natural exit, and
    emits per-trade alpha plus aggregate stats.

    {1 What this measures}

    Raw signal alpha — what each Stage-2 breakout signal would have returned if
    we'd taken every one. Separates {b signal quality} from
    {b portfolio mechanism}:

    - High signal alpha + many portfolio rejections in the actual run →
      portfolio surface needs loosening.
    - Low signal alpha + few rejections → screener cascade needs tightening.
    - High alpha + few rejections + low actual return → optimal-strategy picking
      gap (orderings differ from realised outcome).

    {1 Pipeline}

    The diagnostic operates on the same {b scored candidates} the
    {!Backtest_optimal} track produces:

    1. Scan: {!Stage_transition_scanner.scan_panel} enumerates one candidate per
    (symbol, week) where the system's structural breakout predicate fires —
    drops cascade gates (top-N, grade, macro), keeps the per-candidate breakout
    predicate + price helpers. Macro pass is recorded on each candidate, not
    gated. 2. Score: {!Outcome_scorer.score} forward-walks the panel applying
    the trailing-stop walker + Stage-3 detector and emits the realised exit week
    / price / R-multiple per candidate. 3. {b Grade} (this module): every scored
    candidate becomes one {!trade_record} sized at
    [config.entry_dollars / entry_price] shares — no portfolio-level
    interaction, no cash gate, no sector cap. Aggregate stats roll up across all
    trades.

    {1 Reuse, not duplication}

    The entry/exit semantics are the same byte-for-byte as the optimal-strategy
    track (calls the same pure functions). The only difference is portfolio
    interaction: optimal-strategy's {!Optimal_portfolio_filler} resolves cash +
    sector + sizing; the all-eligible grader skips that entirely.

    {1 Purity}

    Pure function. No I/O, no mutable state. The caller (PR-2 binary) owns
    artefact loading + scan + score; this module only owns the
    grade-and-aggregate phase.

    Authority: GitHub issue #870. *)

open Core

type config = {
  entry_dollars : float;
      (** Fixed dollar amount allocated per signal. Default: $10,000. Each
          trade's [shares] is [entry_dollars /. entry_price] — no rounding,
          since these are diagnostic positions, not real fills. *)
  return_buckets : float list;
      (** Bucket boundaries (as decimal fractions, e.g.
          [[-0.5; -0.2; 0.0; 0.2; 0.5; 1.0]]) for the per-trade return
          distribution histogram. The buckets are half-open intervals:
          [(-inf, b0)], [\[b0, b1)], ..., [\[bn, +inf)]. Default:
          [[-0.5; -0.2; 0.0; 0.2; 0.5; 1.0]] — yields seven buckets: [<-50%],
          [-50..-20%], [-20..0%], [0..20%], [20..50%], [50..100%], [>100%]. *)
}
[@@deriving sexp]
(** Diagnostic configuration. Both knobs configurable per {!default_config} — no
    magic numbers in the implementation. *)

val default_config : config
(** [default_config] =
    [{ entry_dollars = 10_000.0; return_buckets = [-0.5; -0.2; 0.0; 0.2; 0.5;
     1.0] }]. *)

type trade_record = {
  signal_date : Date.t;
      (** Friday on which the breakout predicate fired — the same as
          [scored_candidate.entry.entry_week]. *)
  symbol : string;
  side : Trading_base.Types.position_side;
      (** [Long] for Stage 1→2 breakouts, [Short] for Stage 3→4 breakdowns.
          (PR-1 only sees [Long] candidates because {!Stage_transition_scanner}
          only emits longs today; the field is carried for forward-compatibility
          with the short-side scanner.) *)
  entry_price : float;
      (** Counterfactual entry price — the breakout-week close. Same source as
          [scored_candidate.entry.entry_price]. *)
  exit_date : Date.t;
      (** Friday on which the position closed under the natural exit rule (stop
          hit, Stage-3 transition confirmed, or end of run). *)
  exit_reason : Backtest_optimal.Optimal_types.exit_trigger;
      (** Which natural exit fired. Same
          {!Backtest_optimal.Optimal_types.exit_trigger} variants as the
          optimal-strategy track. *)
  return_pct : float;
      (** Per-trade return as a decimal fraction. For longs:
          [(exit_price -. entry_price) /. entry_price]. For shorts: the mirrored
          expression. Sign carries the direction. *)
  hold_days : int;
      (** Calendar-day difference [exit_date - signal_date]. Day-granularity
          (not week-rounded) to give the histogram more resolution than
          [scored_candidate.hold_weeks]. *)
  entry_dollars : float;
      (** Dollar amount allocated to this signal — equals
          [config.entry_dollars]. Carried on the record so downstream readers
          can verify sizing was uniform. *)
  shares : float;
      (** [entry_dollars /. entry_price]. Float (no rounding) — these are
          diagnostic positions, not real fills. *)
  pnl_dollars : float;
      (** [(exit_price -. entry_price) *. shares] for longs; mirrored for
          shorts. Equivalently [entry_dollars *. return_pct]. *)
  cascade_score : int;
      (** Cascade score the live screener would have assigned at [signal_date].
          Recorded for downstream alpha-by-score-bucket analysis. *)
  passes_macro : bool;
      (** Whether the macro gate at [signal_date] would have admitted this
          candidate. Records both passes and fails so consumers can split the
          aggregate by macro regime without re-running the scan. *)
}
[@@deriving sexp]
(** One row per Stage-2 entry signal. Fixed-dollar sized, naturally exited.

    Schema mirrors the per-trade CSV the issue calls for:
    [[date, symbol, entry_close, exit_date, exit_reason, return_pct, hold_days,
     signal_score]] — plus [side], [entry_dollars], [shares], [pnl_dollars],
    [passes_macro] for downstream cross-tabulation. *)

type aggregate = {
  trade_count : int;
      (** Total number of trades — equal to the input scored-candidate count
          (every signal is taken). *)
  winners : int;  (** Count of trades with [return_pct > 0.0]. *)
  losers : int;
      (** Count of trades with [return_pct < 0.0]. Trades with exactly zero
          return are counted in neither — they are flat. *)
  win_rate_pct : float;
      (** [winners /. trade_count] as a decimal fraction. [0.0] when
          [trade_count = 0]. *)
  mean_return_pct : float;
      (** Arithmetic mean of [trade.return_pct] across all trades. [0.0] when
          [trade_count = 0]. *)
  median_return_pct : float;
      (** Median of [trade.return_pct] across all trades. For an even count, the
          average of the two middle values. [0.0] when [trade_count = 0]. *)
  total_pnl_dollars : float;
      (** Sum of [trade.pnl_dollars] across all trades. Equal to
          [config.entry_dollars *. sum(return_pct)] — the alpha is additive when
          sizing is uniform. *)
  return_buckets : (float * float * int) list;
      (** Per-bucket counts: [(low, high, count)] tuples in the bucket order
          implied by [config.return_buckets]. The first bucket has
          [low = neg_infinity], the last bucket has [high = infinity]. *)
}
[@@deriving sexp]
(** Aggregate stats over [result.trades].
    [trade_count = winners + losers + flat-trades]; flat trades are those with
    exactly [return_pct = 0.0]. *)

type result = { trades : trade_record list; aggregate : aggregate }
[@@deriving sexp]
(** Diagnostic output. [trades] is in the same order as the input scored
    candidates — no re-sorting. *)

val grade :
  config:config ->
  scored:Backtest_optimal.Optimal_types.scored_candidate list ->
  result
(** [grade ~config ~scored] projects each scored candidate into a
    {!trade_record} using [config.entry_dollars] for sizing, computes the
    {!aggregate}, and returns both as a {!result}.

    Trade order matches [scored] order — no resorting. Empty input yields a
    result with [trade_count = 0] and zeroed metrics (no exception).

    Pure function. *)

val build_trade_record :
  config:config ->
  Backtest_optimal.Optimal_types.scored_candidate ->
  trade_record
(** [build_trade_record ~config sc] is the per-candidate projection helper.
    Exposed for unit-testing the per-trade arithmetic in isolation; the
    aggregator at {!grade} uses it internally. *)

val compute_aggregate : config:config -> trade_record list -> aggregate
(** [compute_aggregate ~config trades] computes the {!aggregate} stats over
    [trades]. Exposed for unit-testing the aggregation in isolation; {!grade}
    uses it internally.

    Uses [config.return_buckets] for the histogram boundaries. *)
