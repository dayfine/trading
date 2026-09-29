open Core

(* [groups] is kept verbatim for [sexp_of_t]; [by_symbol] is the lookup as
   (ticker, group id) pairs. A plain assoc list (not a [Map]) on purpose: the
   map rides inside the strategy config, which callers compare structurally,
   and a [Map] carries a comparator closure that polymorphic compare rejects.
   The map is tiny (~50 tickers), so the linear lookup is immaterial. *)
type t = { groups : string list list; by_symbol : (string * string) list }

let empty = { groups = []; by_symbol = [] }
let is_empty t = List.is_empty t.groups

(* A one-ticker group cannot pair anything and is almost certainly a typo. *)
let _min_group_size = 2

let _check_group_size group =
  if List.length group < _min_group_size then
    failwithf "Share_class_map: group (%s) has fewer than %d tickers"
      (String.concat ~sep:" " group)
      _min_group_size ()

(* Every member of [group] paired with the group's id (its first ticker). *)
let _pairs_of_group group =
  _check_group_size group;
  let id = List.hd_exn group in
  List.map group ~f:(fun symbol -> (symbol, id))

(* A ticker listed twice has an ambiguous issuer — fail rather than pick one. *)
let _check_no_duplicate_ticker pairs =
  let by_ticker (a, _) (b, _) = String.compare a b in
  match List.find_a_dup pairs ~compare:by_ticker with
  | Some (symbol, _) ->
      failwithf "Share_class_map: ticker %s is listed in more than one group"
        symbol ()
  | None -> ()

let of_groups groups =
  let by_symbol = List.concat_map groups ~f:_pairs_of_group in
  _check_no_duplicate_ticker by_symbol;
  { groups; by_symbol }

let groups t = t.groups
let group_of t symbol = List.Assoc.find t.by_symbol ~equal:String.equal symbol
let t_of_sexp sexp = of_groups ([%of_sexp: string list list] sexp)
let sexp_of_t t = [%sexp_of: string list list] t.groups
let default_file_name = "share_classes.sexp"

let load path =
  if not (Stdlib.Sys.file_exists path) then
    failwithf "Share_class_map.load: share-class map not found at %s" path ()
  else
    try t_of_sexp (Sexp.load_sexp path)
    with exn ->
      failwithf "Share_class_map.load: malformed share-class map %s: %s" path
        (Exn.to_string exn) ()
