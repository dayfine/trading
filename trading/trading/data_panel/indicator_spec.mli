(** Identifier for one entry in an indicator-panel registry.

    A [t] keys an output panel by indicator-name + period + cadence. The triple
    is the granularity at which the strategy's [get_indicator_fn] resolves
    indicator values: ["EMA"], 50, [Daily] yields the EMA-50 daily panel.

    Cadence is currently always [Daily] in Stage 1; weekly indicators land in
    Stage 4. The field is included now so the registry's lookup contract does
    not change when weekly cadence arrives. *)

type t = {
  name : string;
      (** Indicator name, e.g. ["EMA"], ["SMA"], ["ATR"], ["RSI"]. *)
  period : int;
      (** Lookback window. Must be [>= 1]. The kernel decides what the period
          means (number of input values for SMA, smoothing factor numerator for
          EMA, Wilder smoothing window for ATR/RSI). *)
  cadence : Types.Cadence.t;
}
[@@deriving sexp, eq, compare, hash]

val to_string : t -> string
(** Human-readable form, e.g. ["EMA-50-Daily"]. Used in error messages and the
    registry's missing-spec lookup failure. *)
