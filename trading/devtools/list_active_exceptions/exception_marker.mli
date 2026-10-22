(** Scan OCaml comment markers without treating quoted marker text as an
    annotation. *)

type module_entry = {
  file : string;
  line_count : int;
  reason : string;
  review_at : string option;
  status : string;
}
(** An inline module marker and its review status. *)

type function_entry = {
  file_line : string;
  fn_name : string;
  fn_reason : string;
  fn_review_at : string option;
  fn_status : string;
}
(** An inline function marker and its review status. *)

val scan_file : string -> module_entry list * function_entry list
(** Scan one file in source order, retaining module line counts and function
    locations. Raises [Sys_error] when the file cannot be opened. *)
