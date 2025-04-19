(** Standard status codes and types for the trading system.
    Based on Abseil's status codes: https://abseil.io/docs/cpp/guides/status-codes *)

(** Status codes that can occur during operations *)
type code =
  | Ok
  | Cancelled
  | Invalid_argument
  | Deadline_exceeded
  | NotFound
  | Already_exists
  | Permission_denied
  | Unauthenticated
  | Resource_exhausted
  | Failed_precondition
  | Aborted
  | Unavailable
  | Out_of_range
  | Unimplemented
  | Internal
  | Data_loss
  | Unknown
[@@deriving show, eq]

(** A status consists of a code and a descriptive message *)
type t = {
  code : code;
  message : string;
}
[@@deriving show, eq]

(** [to_string status] converts a status to a human-readable string *)
val to_string : t -> string

(** [is_ok status] returns true if the status code is Ok *)
val is_ok : t -> bool

(** [is_error status] returns true if the status code is not Ok *)
val is_error : t -> bool
