(** {1 Types} *)

(** Current stop management state for a single position. *)
type stop_state =
  | Initial of {
      stop_level : float;  (** Current stop price *)
      reference_level : float;
          (** Support floor (long) or resistance ceiling (short) at entry *)
    }
  | Trailing of {
      stop_level : float;
          (** Current stop price — never moved against position *)
      last_correction_extreme : float;
          (** Extreme of most recent correction: Long = pullback low; Short =
              counter-rally high *)
      last_trend_extreme : float;
          (** Extreme of most recent trend leg: Long = rally peak; Short =
              decline trough *)
      ma_at_last_adjustment : float;
          (** 30-week MA value when stop was last adjusted *)
      correction_count : int;  (** Number of correction cycles completed *)
      correction_observed_since_reset : bool;
          (** Whether a real counter-move bar has touched/breached the running
              [last_correction_extreme] since the last cycle reset (or, for
              [correction_count = 0], since the [Initial → Trailing]
              transition).

              Used to gate phantom cycles after a cycle reset: when the
              correction extreme is reset to [bar.close_price] on cycle
              completion, monotonic price action in the trend's favour can
              accumulate a stale [last_correction_extreme] that the cycle math
              would otherwise pair with a fresh trend extreme to phantom-fire a
              new cycle. The first cycle (count = 0) is allowed to fire on the
              entry-bar-extreme seed regardless of this flag — that pre-entry
              extreme represents the breakout/breakdown reference point, which
              is a legitimate Weinstein anchor (book §Stop-Loss Rules). *)
    }
  | Tightened of {
      stop_level : float;
          (** Current stop price — closer to market than Trailing *)
      last_correction_extreme : float;
          (** Extreme of most recent correction (see [Trailing] docs) *)
      reason : string;  (** Why tightening was triggered *)
    }
[@@deriving show, eq, sexp]

(** Event produced by [update] describing what happened to the stop. *)
type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
      (** Price crossed the stop level — position should be exited *)
  | Stop_raised of { old_level : float; new_level : float; reason : string }
      (** Stop level was adjusted in the position's favour (raised for long,
          lowered for short) *)
  | Entered_tightening of { reason : string }
      (** Transitioned from Trailing to Tightened *)
  | No_change  (** No adjustment this period *)
[@@deriving show, eq, sexp]

type config = {
  round_number_nudge : float;
      (** Distance from round number that triggers a nudge (default: 0.125). *)
  min_correction_pct : float;
      (** Minimum pullback to qualify as a correction (default: 0.08 = 8%).

          Future improvement: derive this threshold from the security's
          historical or implied volatility rather than using a fixed value. A
          more volatile stock needs a wider threshold to avoid counting noise as
          a meaningful correction. *)
  tighten_on_flat_ma : bool;
      (** Whether to tighten stops when the 30-week MA flattens (default: true).
      *)
  ma_flat_threshold : float;
      (** MA slope threshold below which MA is considered flat (default: 0.002).
      *)
  trailing_stop_buffer_pct : float;
      (** Buffer applied below a correction low (long) or above a correction
          high (short) when computing a trailing stop candidate (default: 0.01 =
          1%). *)
  tightened_stop_buffer_pct : float;
      (** Tighter buffer used in the Tightened state (default: 0.005 = 0.5%).
          Smaller than [trailing_stop_buffer_pct] to keep the stop close to
          market once tightening is triggered. *)
  support_floor_lookback_bars : int;
      (** Daily-bar lookback window for the support-floor primitive (default: 90
          bars ≈ 4.5 months). Large enough to capture a recent correction,
          narrow enough to avoid reaching into a prior regime. Used by
          {!Weinstein_stops.compute_initial_stop_with_floor}; depth threshold is
          shared with [min_correction_pct] (Weinstein's 8% rule). *)
  max_stop_distance_pct : float;
      (** G15 step 3: maximum allowed distance between entry price and the
          installed initial stop, as a fraction of entry price (default: 0.15 =
          15%). When [|installed_stop - entry| / entry > max_stop_distance_pct],
          the candidate is rejected at the strategy's entry-decision site with a
          [Stop_too_wide] skip reason rather than admitted with an oversized
          structural stop.

          Implements Weinstein book §5.1 ("Initial Stop Placement"): "if a stop
          requires more than 15% risk → prefer other candidates". The gate fires
          symmetrically on longs and shorts — both the long correction-low floor
          and the short counter-rally-high floor can land structurally far from
          entry, and the historical sp500-2019-2023 cascade that motivated this
          fix was driven by short candidates whose support-floor-derived stop
          sat 16%+ above entry (AOS, HOOD; see
          [dev/notes/g15-stops-diagnostic-aos-hood-2026-05-01.md]). *)
  trigger_on_weekly_close : bool; [@sexp.default false]
      (** When [true], a stop fires only when the bar's {b close} crosses the
          stop level, not its intra-bar low (long) / high (short). On the weekly
          strategy cadence the bar is a weekly bar, so this is Weinstein's
          weekly-{e close} rule (book §Stop-Loss Rules, the qc-behavioral L3
          contract): an intra-week shakeout wick below the stop does {b not}
          trigger an exit if the week closes back above it.

          Default [false] reproduces the prior intra-bar GTC-stop behaviour
          bit-for-bit (longs trigger on [low ≤ stop], shorts on [high ≥ stop]),
          so every existing golden replays unchanged. Default-off experiment
          axis per [.claude/rules/experiment-flag-discipline.md]; design
          [dev/plans/weekly-close-stop-2026-06-19.md]. *)
  vol_scaled_stop_atr_mult : float; [@sexp.default 0.0]
      (** Volatility-scaled minimum installed-stop distance (default-off). When
          [> 0.0], the {e minimum} distance the installed initial stop must sit
          from entry is widened from the fixed [installed_stop_min_pct] floor to
          [Float.max installed_stop_min_pct (vol_scaled_stop_atr_mult *.
           atr_pct)], where [atr_pct = ATR / entry_price] and [ATR] is the
          {!Atr.atr} over the candidate's recent daily bars
          ([vol_scaled_stop_atr_period]). The [Float.max] means the floor only
          ever {b widens}: a high-volatility name gets a structurally wider stop
          while a low-volatility name keeps the existing 8% floor, and the
          [max_stop_distance_pct] reject cap still applies {e after} so a
          vol-widened stop that exceeds the cap rejects the candidate.

          Why: the live stop is whipsaw-dominated (it forgoes more upside than
          disaster it dodges — see
          [dev/agent-memory/project_weekly_close_stop_lever.md]
          §stop-quality-levers). A fixed minimum buffer whipsaws volatile names
          with the same distance that fits quiet names. Scaling the
          {e minimum distance} to ATR cuts whipsaw at its source without holding
          genuine breakdowns deeper (the flaw that got [trigger_on_weekly_close]
          rejected). This is the [min_correction_pct] docstring's own flagged
          improvement ("derive this threshold from the security's volatility").

          Faithful-core: this is the {b initial-stop-placement dial} (book §5.1
          + the volatility caveat) — the spine (structural support-floor stop,
            never-loosen rule, weekly cadence) is untouched; only the
            minimum-distance floor widens. Default [0.0] is an exact no-op
            ([Float.max base 0.0 = base]) so every existing golden replays
            unchanged. Default-off experiment axis per
            [.claude/rules/experiment-flag-discipline.md] /
            [.claude/rules/weinstein-faithful-core.md]; promoted only on a
            ledger ACCEPT. *)
  vol_scaled_stop_atr_period : int; [@sexp.default 14]
      (** ATR lookback period (in daily bars) for [vol_scaled_stop_atr_mult].
          Consulted only when [vol_scaled_stop_atr_mult > 0.0]; the standard
          Wilder 14-day period (see {!Atr.atr}). *)
}
[@@deriving show, eq, sexp]
(** Configuration for stop management behavior. All thresholds are configurable
    so backtesting can tune them. *)

(** {1 Default Config} *)

val default_config : config
(** Default configuration using Weinstein book values. *)
