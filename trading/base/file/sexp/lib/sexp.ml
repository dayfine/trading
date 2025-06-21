let save (type a) (module S : Base.Sexpable.S with type t = a) (value : a)
    ~(path : Fpath.t) : Status.status =
  let open Bos in
  let data = Sexp_pretty.sexp_to_string (S.sexp_of_t value) in
  match OS.File.write path data with
  | Ok () -> Status.ok ()
  | Error (`Msg msg) -> Status.error_internal msg

let load (type a) (module S : Base.Sexpable.S with type t = a) ~(path : Fpath.t)
    : a Status.status_or =
  let open Bos in
  match OS.File.exists path with
  | Error (`Msg msg) -> Status.error_internal msg
  | Ok false -> Status.error_not_found (Fpath.to_string path)
  | Ok true -> (
      match OS.File.read path with
      | Error (`Msg msg) -> Status.error_internal msg
      | Ok contents -> Ok (Sexplib.Sexp.of_string contents |> S.t_of_sexp))
