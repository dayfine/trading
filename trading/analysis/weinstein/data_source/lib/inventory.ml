open Core

type entry = {
  symbol : string;
  data_start_date : Date.t;
  data_end_date : Date.t;
}
[@@deriving sexp]

type t = { generated_at : Date.t; symbols : entry list } [@@deriving sexp]

let path ~data_dir = Fpath.(data_dir / "inventory.sexp")

let _entry_of_metadata (meta : Metadata.t) =
  {
    symbol = meta.symbol;
    data_start_date = meta.data_start_date;
    data_end_date = meta.data_end_date;
  }

let _stat_kind path =
  match Bos.OS.Path.stat path with
  | Error _ -> None
  | Ok stat -> Some stat.Caml_unix.st_kind

let _dispatch_entry ~walk ~f entry =
  match _stat_kind entry with
  | Some Caml_unix.S_DIR -> walk entry ~f
  | Some Caml_unix.S_REG -> f entry
  | _ -> ()

let rec _walk_dir dir ~f =
  match Bos.OS.Dir.contents dir with
  | Error (`Msg msg) ->
      Printf.eprintf "Warning: cannot read directory %s: %s\n"
        (Fpath.to_string dir) msg
  | Ok entries -> List.iter entries ~f:(_dispatch_entry ~walk:_walk_dir ~f)

let build ~data_dir =
  let entries = ref [] in
  _walk_dir data_dir ~f:(fun fpath ->
      if String.equal (Fpath.filename fpath) "data.metadata.sexp" then
        match File_sexp.Sexp.load (module Metadata.T_sexp) ~path:fpath with
        | Error _ -> ()
        | Ok meta -> entries := _entry_of_metadata meta :: !entries);
  let symbols =
    List.sort !entries ~compare:(fun a b -> String.compare a.symbol b.symbol)
  in
  { generated_at = Date.today ~zone:Time_float.Zone.utc; symbols }

let _sexpable () =
  (* Build a Sexpable module from the already-derived functions so we can
     use File_sexp.Sexp without duplicating the type definition. *)
  (module struct
    type nonrec t = t

    let sexp_of_t = sexp_of_t
    let t_of_sexp = t_of_sexp
  end : Base.Sexpable.S
    with type t = t)

let save t ~data_dir =
  File_sexp.Sexp.save (_sexpable ()) t ~path:(path ~data_dir)

let load ~data_dir = File_sexp.Sexp.load (_sexpable ()) ~path:(path ~data_dir)
