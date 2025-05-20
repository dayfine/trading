open Core

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

let to_string { code; message } =
  match code with
  | Ok -> "OK"
  | _ -> sprintf "%s: %s" (show_code code) message

let is_ok { code; _ } = equal_code code Ok
let is_error status = not (is_ok status)

(** Error creation functions *)
let invalid_argument_error message = { code = Invalid_argument; message }

let internal_error message = { code = Internal; message }
let not_found_error message = { code = NotFound; message }
let permission_denied_error message = { code = Permission_denied; message }

let combine statuses =
  let errors = List.filter ~f:is_error statuses in
  match errors with
  | [] -> { code = Ok; message = "" }
  | first_error :: rest ->
      let combined_message =
        match rest with
        | [] -> first_error.message
        | _ ->
            let error_messages =
              first_error.message
              :: List.map rest ~f:(fun s -> s.message)
            in
            String.concat ~sep:"; " error_messages
      in
      { code = first_error.code; message = combined_message }
