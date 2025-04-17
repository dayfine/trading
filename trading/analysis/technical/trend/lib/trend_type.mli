(** Type representing trend directions in time series data *)

type t =
  | Increasing  (** Positive slope above minimum threshold *)
  | Decreasing  (** Negative slope below minimum threshold *)
  | Flat  (** Slope between minimum and maximum thresholds *)
  | Unknown  (** Insufficient data or poor fit *)
[@@deriving show, eq]

val to_string : t -> string
(** Convert a trend to its string representation *)
