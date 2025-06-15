let save (type a) (module S : Base.Sexpable.S with type t = a) (value : a)
    ~(path : Fpath.t) : unit =
  let open Bos in
  let data = Sexp_pretty.sexp_to_string (S.sexp_of_t value) in
  match OS.File.write path data with
  | Ok () -> ()
  | Error (`Msg msg) -> failwith msg

let load (type a) (module S : Base.Sexpable.S with type t = a) ~(path : Fpath.t)
    : a option =
  let open Bos in
  match OS.File.exists path with
  | Ok true -> (
      match OS.File.read path with
      | Ok contents -> Some (Sexplib.Sexp.of_string contents |> S.t_of_sexp)
      | Error (`Msg msg) -> failwith msg)
  | Ok false -> None
  | Error (`Msg msg) -> failwith msg
