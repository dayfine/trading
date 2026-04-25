(** Registry mapping {!Indicator_spec.t} → owned [N x T] [Float64] panel.

    The registry holds OWNED Bigarrays — allocated at [create] time, lifetime
    tied to the registry. Each registered spec gets a single output panel; some
    indicators (RSI) also allocate scratch panels for their persistent state
    (avg_gain / avg_loss).

    On each tick the runner calls {!advance_all} once. The registry then
    iterates its specs in registration order and dispatches to the appropriate
    kernel ([Ema_kernel.advance], [Sma_kernel.advance], etc.).

    Stage 1 supports daily-cadence kernels for ["EMA"], ["SMA"], ["ATR"], and
    ["RSI"]. Other names raise [Failure] at [create] time. Weekly cadence and
    additional indicator names (Stage, Volume, Resistance, RS_line) land in
    Stage 4. *)

type t

val create :
  symbol_index:Symbol_index.t -> n_days:int -> specs:Indicator_spec.t list -> t
(** [create ~symbol_index ~n_days ~specs] allocates one [N x n_days] output
    panel per spec (and additional scratch panels for indicators that need
    them). Panels are NaN-initialised.

    Raises [Failure] if any spec has a name not in the supported set, a
    non-positive period, or a non-[Daily] cadence (Stage 1 limitation).
    Duplicate specs are tolerated — they share the same output panel. *)

val n : t -> int
(** [n t] is the universe size (panel row count). *)

val n_days : t -> int
(** [n_days t] is the day-axis length (panel column count). *)

val symbol_index : t -> Symbol_index.t
(** [symbol_index t] is the bijection used to construct [t]. *)

val specs : t -> Indicator_spec.t list
(** [specs t] is the registered specs in registration order. *)

val get :
  t ->
  Indicator_spec.t ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
(** [get t spec] returns the output panel for [spec]. Raises [Not_found_s] if
    the spec was not registered at [create]. *)

val advance_all : t -> ohlcv:Ohlcv_panels.t -> t:int -> unit
(** [advance_all t ~ohlcv ~t:tick] calls each registered kernel's [advance] for
    column [tick], reading inputs from [ohlcv] and writing outputs into the
    registry's panels.

    Caller must ensure [tick] is within the half-open range [0..n_days t - 1].
    [ohlcv] must have matching shape (same [n] and [n_days]). Pure side-effect
    on the registry's Bigarrays; no allocation per call. *)
