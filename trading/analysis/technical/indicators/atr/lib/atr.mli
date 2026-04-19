(** Average True Range (ATR) — a volatility indicator (Wilder, 1978).

    True Range for a bar is the greatest of:
    - the bar's high − low range,
    - the absolute gap between the prior close and the bar's high,
    - the absolute gap between the prior close and the bar's low.

    ATR-N is the simple mean of the last [N] true-range values. *)

open Types

val true_range : prev_close:float -> Daily_price.t -> float
(** [true_range ~prev_close bar] is the True Range component for [bar] given the
    prior bar's close. Always non-negative. *)

val true_range_series : Daily_price.t list -> float list
(** [true_range_series bars] returns the per-bar True Range values for
    chronologically ordered [bars], skipping the first bar (no prior close
    available). Output length is [List.length bars - 1] for inputs of length ≥
    2; empty for shorter inputs. *)

val atr : period:int -> Daily_price.t list -> float option
(** [atr ~period bars] is the simple mean of the last [period] True Range values
    from [bars] (chronologically ordered). Returns [None] when there are fewer
    than [period + 1] bars (the first is skipped — see {!true_range_series}).
    [period] must be positive. *)
