(** Exit-trigger types and their pure classifiers. {!Stop_log} [include]s this
    module, so every name here is also [Stop_log.<name>]; [stop_log.mli] holds
    the full documented contract. Split out of [stop_log.ml] (issue #3127) to
    keep the collector under the file-length limit. *)

open Trading_strategy

(** Why the position was exited, as recorded from the strategy's transition. *)
type exit_trigger =
  | Stop_loss of { stop_price : float; actual_price : float }
  | Take_profit of { target_price : float; actual_price : float }
  | Signal_reversal of { description : string }
  | Time_expired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | Portfolio_rebalancing
  | Strategy_signal of { label : string; detail : string option }
  | End_of_period
[@@deriving show, eq, sexp]

val exit_trigger_of_reason : Position.exit_reason -> exit_trigger
(** Translate a strategy-emitted {!Position.exit_reason} into an
    {!exit_trigger}. *)

val with_fill_price : exit_trigger -> fill_price:float -> exit_trigger
(** Replace a stop-loss or take-profit trigger's [actual_price] with the
    executed fill price; every other trigger is returned unchanged. *)

(** How a stop-driven exit fired; see [Stop_log.stop_trigger_kind]. *)
type stop_trigger_kind =
  | Gap_through
  | Intraday
  | End_of_period
  | Non_stop_exit
[@@deriving show, eq, sexp]

val gap_down_threshold_pct : float
(** Gap past the stop, as a fraction of the stop price, that makes a fill a
    {!Gap_through} rather than {!Intraday}. *)

val classify_stop_trigger_kind :
  ?gap_threshold_pct:float ->
  side:Trading_base.Types.position_side ->
  exit_trigger ->
  stop_trigger_kind
(** Classify a trigger by the gap between its stop level and its fill; see
    [Stop_log.classify_stop_trigger_kind]. *)
