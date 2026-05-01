(** Module for creating orders from structured data *)

open Trading_base.Types
open Status
open Types

type order_params = {
  symbol : symbol;
  side : side;
  order_type : order_type;
  quantity : quantity;
  time_in_force : time_in_force;
}
[@@deriving show, eq]
(** Order creation parameters *)

val create_order :
  ?now_time:Time_ns_unix.t -> ?id:order_id -> order_params -> order status_or
(** Create an order from structured parameters with validation.

    [id] is the order identifier. When omitted, a deterministic
    process-monotonic counter is used ("ord-1", "ord-2", ...). The default is
    intentionally independent of wall-clock time and the OCaml [Random] PRNG so
    that:

    - Two structurally identical sequences of [create_order] calls in the same
      process produce the same IDs.
    - Long-horizon backtests are not perturbed by sub-second clock drift across
      forks (see G6: hashtable bucket placement of [Manager.orders] depends on
      [Hash.hash id], so unstable IDs cause unstable [list_orders] iteration
      order, which propagates into different fill order, sizing, and metrics).

    Callers that need scenario-time-keyed IDs (e.g. [Order_generator] threads in
    a [(date, seq)]-derived id from the simulator) should pass [~id] explicitly.
*)
