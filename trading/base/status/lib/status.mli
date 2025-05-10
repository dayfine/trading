(** Standard status codes and types for the trading system. Based on Abseil's
    status codes: https://abseil.io/docs/cpp/guides/status-codes *)

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

type t = { code : code; message : string } [@@deriving show, eq]
(** A status consists of a code and a descriptive message *)

val to_string : t -> string
(** [to_string status] converts a status to a human-readable string *)

val is_ok : t -> bool
(** [is_ok status] returns true if the status code is Ok *)

val is_error : t -> bool
(** [is_error status] returns true if the status code is not Ok *)

(** Error creation functions *)
val invalid_argument_error : string -> t
(** [invalid_argument_error message] creates a status with Invalid_argument code *)

val not_found_error : string -> t
(** [not_found_error message] creates a status with NotFound code *)

val permission_denied_error : string -> t
(** [permission_denied_error message] creates a status with Permission_denied code *)
