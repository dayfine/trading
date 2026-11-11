(** Synth-v2 — regime-switching GARCH price-series generator.

    Combines the [Regime_hmm] regime layer with per-regime [Garch] volatility
    and per-regime drift to emit a deterministic [Daily_price.t list].

    Pipeline:
    {v
      1. sample regime path [r_0 .. r_{N-1}] from the HMM
      2. for each step k, draw a GARCH return ε_k using the GARCH params
         attached to regime r_k. The GARCH state (variance) is carried
         forward across steps but parameters switch when the regime switches.
      3. add the per-regime drift μ_{r_k} to ε_k to obtain the log-return.
      4. build a price chain by compounding log-returns on top of [start_price]
         and emit OHLCV bars with synthetic intra-day shape (close ± 0.5%).
    v}

    Determinism: same [config] produces an identical output. The HMM and the
    GARCH series share [seed]: the HMM uses [seed] directly; the GARCH layer
    uses [seed + 1] so the two streams are independent.

    Calibration TODO: per-regime GARCH params and drifts are currently hand-set
    defaults intended to roughly match historical SPY regime characteristics. A
    follow-up PR will fit them from real history. *)

type config = {
  hmm : Regime_hmm.t;
  garch_per_regime : (Regime_hmm.regime * Garch.params) list;
      (** Must contain entries for all three regimes. *)
  drift_per_regime : (Regime_hmm.regime * float) list;
      (** Per-step (per-day) log-return drift added to the GARCH shock. Must
          contain entries for all three regimes. *)
  start_price : float;  (** First bar's close, must be > 0. *)
  target_length_days : int;  (** Number of bars to emit, must be > 0. *)
  start_date : Core.Date.t;
      (** First bar's date; subsequent bars advance one business day at a time
          (Mon-Fri). Holidays are ignored. *)
  seed : int;
      (** Master seed. The HMM uses [seed]; the GARCH layer uses [seed + 1]. *)
}

val default_garch_per_regime : (Regime_hmm.regime * Garch.params) list
(** Hand-set per-regime GARCH parameters. Documented in the module-level
    comment. Roughly:
    - Bull: omega=1e-6, alpha=0.05, beta=0.93 — annualised vol ~12%
    - Bear: omega=1e-5, alpha=0.10, beta=0.85 — annualised vol ~25%
    - Crisis: omega=5e-5, alpha=0.20, beta=0.75 — annualised vol ~60%

    Calibration TODO: re-fit per regime from real history. *)

val default_drift_per_regime : (Regime_hmm.regime * float) list
(** Hand-set per-regime per-day log-return drifts:
    - Bull: +0.0005/day (~13% annualised)
    - Bear: -0.0003/day (~-7.5% annualised)
    - Crisis: -0.002/day (~-50% annualised over a sustained crisis; mitigated by
      short mean duration). *)

val default_config :
  start_date:Core.Date.t ->
  start_price:float ->
  target_length_days:int ->
  seed:int ->
  config
(** Convenience constructor wiring up [Regime_hmm.default],
    [default_garch_per_regime], and [default_drift_per_regime]. *)

val generate : config -> (Types.Daily_price.t list, Status.t) Result.t
(** [generate config] returns a synthetic daily-price list of length
    [config.target_length_days].

    Returns [Error Status.Invalid_argument] when:
    - [config.target_length_days <= 0]
    - [config.start_price <= 0]
    - [config.hmm] fails [Regime_hmm.validate]
    - [config.garch_per_regime] is missing any regime or any params fail
      [Garch.validate]
    - [config.drift_per_regime] is missing any regime. *)
