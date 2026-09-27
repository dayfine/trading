(** The split corpus loader. See [split_corpus.mli]. *)

open Core

type shape = Forward | Reverse | Two_in_window [@@deriving sexp]

type split = {
  ex_date : Date.t;
  ratio : float;
  factor_before : float;
  factor_after : float;
}
[@@deriving sexp]

type meta = {
  symbol : string;
  shape : shape;
  splits : split list;
  note : string;
}
[@@deriving sexp]

type entry = { name : string; meta : meta; bars : Types.Daily_price.t list }

let corpus_subdir = "trading/test_data/split_corpus"

(* How far above the cwd to search: [dune runtest] runs from
   [_build/default/trading/weinstein/split_corpus/test], six levels below the
   checkout root. *)
let max_walk_up = 10

let adjustment_factor (bar : Types.Daily_price.t) =
  bar.adjusted_close /. bar.close_price

let _is_dir path = try Stdlib.Sys.is_directory path with Sys_error _ -> false

let find_root () =
  let rec walk dir tries_left =
    let candidate = Filename.concat dir corpus_subdir in
    if tries_left = 0 then None
    else if _is_dir candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if String.equal parent dir then None else walk parent (tries_left - 1)
  in
  walk (Stdlib.Sys.getcwd ()) max_walk_up

let entry_names ~root =
  Stdlib.Sys.readdir root |> Array.to_list
  |> List.filter ~f:(fun name -> _is_dir (Filename.concat root name))
  |> List.sort ~compare:String.compare

let _load_bars dir =
  let path = Filename.concat dir "bars.csv" in
  match Csv.Parser.parse_lines (In_channel.read_lines path) with
  | Ok bars -> bars
  | Error (status : Status.t) ->
      failwithf "split corpus: %s: %s" path status.message ()

let _load_meta dir =
  meta_of_sexp (Sexp.load_sexp (Filename.concat dir "meta.sexp"))

let load ~root name =
  let dir = Filename.concat root name in
  { name; meta = _load_meta dir; bars = _load_bars dir }

let load_all ~root = List.map (entry_names ~root) ~f:(load ~root)
