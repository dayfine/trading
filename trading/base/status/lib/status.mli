open Core

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

type 'a status_or = ('a, t) Result.t
(** A type alias for [Result.t] with [Status.t] as the error type. Use this for
    functions that return a result with a status error. *)

type status = unit status_or
(** A type alias for a unit result with a status error. Use this for functions
    that that returns no data that might fail. *)

val is_ok : t -> bool
(** [is_ok status] returns true if the status code is Ok *)

val is_error : t -> bool
(** [is_error status] returns true if the status code is not Ok *)

val ok : unit -> status
(** [ok] creates a status with Ok code *)

(** Error creation functions *)
val invalid_argument_error : string -> t
(** [invalid_argument_error message] creates a status with Invalid_argument code
*)

val internal_error : string -> t
(** [internal_error message] creates a status with Internal code *)

val not_found_error : string -> t
(** [not_found_error message] creates a status with NotFound code *)

val permission_denied_error : string -> t
(** [permission_denied_error message] creates a status with Permission_denied
    code *)

val combine : t list -> t
(** [combine statuses] combines a list of statuses into a single status.
    - If all statuses are Ok, returns Ok
    - If any status is an error, returns a combined error status with:
    - The first error code from the list
    - A message that combines all error messages *)

val combine_status_list : status list -> status
(** [combine_status_list status_list] combines a list of status results.
    - If all are Ok, returns Ok ()
    - If any are Error, returns the combined error status *)

val error_invalid_argument : string -> 'a status_or
(** [error_invalid_argument msg] returns [Error (invalid_argument_error msg)].
    Use for invalid argument errors in result-returning functions. *)

val error_internal : string -> 'a status_or
(** [error_internal msg] returns [Error (internal_error msg)]. Use for internal
    errors in result-returning functions. *)

val error_not_found : string -> 'a status_or
(** [error_not_found msg] returns [Error (not_found_error msg)]. Use for not
    found errors in result-returning functions. *)

val error_permission_denied : string -> 'a status_or
(** [error_permission_denied msg] returns [Error (permission_denied_error msg)].
    Use for permission denied errors in result-returning functions. *)
