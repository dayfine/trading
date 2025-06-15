open Core

type entry = { symbol : string; csv_path : Fpath.t } [@@deriving show, eq]
type t = { hash_table : (string, entry) Hashtbl.t }

(* Extract the symbol from the path, which is the last component of the path *)
let _extract_symbol_from_path path =
  match String.split ~on:'/' path |> List.rev with
  | _filename :: symbol :: _ -> symbol
  | _ -> failwith "Path does not contain enough components to extract symbol"

let _list_csv_files_in_dir dir =
  match
    Bos.OS.Dir.fold_contents ~elements:`Files
      (fun p acc ->
        let path = Fpath.to_string p in
        if String.is_suffix ~suffix:".csv" path then path :: acc else acc)
      [] (Fpath.v dir)
  with
  | Ok files -> files
  | Error (`Msg msg) -> failwith msg

let create ~csv_dir =
  let hash_table = Hashtbl.create (module String) in
  let files = _list_csv_files_in_dir csv_dir in
  List.iter files ~f:(fun path ->
      let symbol = _extract_symbol_from_path path in
      Hashtbl.set hash_table ~key:symbol
        ~data:{ symbol; csv_path = Fpath.v path });
  { hash_table }

let get t ~symbol =
  match Hashtbl.find t.hash_table symbol with
  | Some entry -> Some entry
  | None -> None

let list t =
  Hashtbl.to_alist t.hash_table |> List.map ~f:(fun (_, entry) -> entry)
