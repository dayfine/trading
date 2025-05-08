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

let code_to_string = function
  | Ok -> "OK"
  | Cancelled -> "CANCELLED"
  | Invalid_argument -> "INVALID_ARGUMENT"
  | Deadline_exceeded -> "DEADLINE_EXCEEDED"
  | NotFound -> "NOT_FOUND"
  | Already_exists -> "ALREADY_EXISTS"
  | Permission_denied -> "PERMISSION_DENIED"
  | Unauthenticated -> "UNAUTHENTICATED"
  | Resource_exhausted -> "RESOURCE_EXHAUSTED"
  | Failed_precondition -> "FAILED_PRECONDITION"
  | Aborted -> "ABORTED"
  | Unavailable -> "UNAVAILABLE"
  | Out_of_range -> "OUT_OF_RANGE"
  | Unimplemented -> "UNIMPLEMENTED"
  | Internal -> "INTERNAL"
  | Data_loss -> "DATA_LOSS"
  | Unknown -> "UNKNOWN"

let to_string { code; message } =
  Printf.sprintf "%s: %s" (code_to_string code) message

let is_ok { code; _ } = code = Ok
let is_error status = not (is_ok status)

(** Error creation functions *)
let invalid_argument_error message = { code = Invalid_argument; message }
let not_found_error message = { code = NotFound; message }
let permission_denied_error message = { code = Permission_denied; message }
