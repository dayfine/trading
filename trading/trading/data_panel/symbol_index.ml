open Core

type t = {
  symbols : string array; (* row index -> symbol *)
  index : (string, int) Hashtbl.t; (* symbol -> row index *)
}

let _find_duplicate (symbols : string list) : string option =
  let seen = Hashtbl.create (module String) in
  List.find symbols ~f:(fun sym ->
      match Hashtbl.add seen ~key:sym ~data:() with
      | `Ok -> false
      | `Duplicate -> true)

let _find_empty (symbols : string list) : bool =
  List.exists symbols ~f:String.is_empty

let create ~universe =
  if _find_empty universe then
    Status.error_invalid_argument "Symbol_index: universe contains empty symbol"
  else
    match _find_duplicate universe with
    | Some dup ->
        Status.error_invalid_argument
          (Printf.sprintf "Symbol_index: duplicate symbol %s" dup)
    | None ->
        let symbols = Array.of_list universe in
        let index = Hashtbl.create (module String) in
        Array.iteri symbols ~f:(fun i sym -> Hashtbl.set index ~key:sym ~data:i);
        Ok { symbols; index }

let to_row t symbol = Hashtbl.find t.index symbol

let of_row t i =
  if i < 0 || i >= Array.length t.symbols then
    invalid_arg
      (Printf.sprintf "Symbol_index.of_row: index %d out of range [0, %d)" i
         (Array.length t.symbols))
  else t.symbols.(i)

let n t = Array.length t.symbols
let symbols t = Array.to_list t.symbols
