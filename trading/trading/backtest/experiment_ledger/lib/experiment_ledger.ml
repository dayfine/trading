open Core

type verdict = Accept | Reject | Inconclusive [@@deriving sexp, eq]

type fold_aggregate = {
  mean_sharpe : float;
  mean_calmar : float;
  mean_return_pct : float;
  mean_max_drawdown_pct : float;
}
[@@deriving sexp]

type variant_record = {
  label : string;
  config_hash : string;
  aggregate : fold_aggregate option;
}
[@@deriving sexp]

type entry = {
  date : string;
  slug : string;
  hypothesis : string;
  base_scenario : string;
  window_id : string;
  baseline_label : string;
  variants : variant_record list;
  verdict : verdict;
  notes : string;
}
[@@deriving sexp]

type index_row = {
  config_hash : string;
  base_scenario : string;
  window_id : string;
  verdict : verdict;
  entry_slug : string;
}
[@@deriving sexp]

(* The universe/index symbol is irrelevant to override key-resolution and to the
   parts of the config the hash is keyed on changing — a placeholder suffices,
   matching [Variant_matrix]'s convention. *)
let _index_symbol = "GSPC.INDX"

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ]
    ~index_symbol:_index_symbol

let config_hash (overrides : Sexp.t list) : string =
  let effective =
    Backtest.Overlay_validator.apply_overrides (_default_config ()) overrides
  in
  let canonical =
    Sexp.to_string_mach (Weinstein_strategy.sexp_of_config effective)
  in
  Md5.to_hex (Md5.digest_string canonical)

let save_entry ~dir (entry : entry) : unit =
  let path = Filename.concat dir (sprintf "%s-%s.sexp" entry.date entry.slug) in
  if Sys_unix.file_exists_exn path then
    failwithf
      "Experiment_ledger.save_entry: %s already exists (append-only ledger, \
       never overwrite)"
      path ();
  Sexp.save_hum path (sexp_of_entry entry)

let load_entry (path : string) : entry = entry_of_sexp (Sexp.load_sexp path)

let load_index ~dir : entry list =
  Sys_unix.readdir dir |> Array.to_list
  |> List.filter ~f:(fun name ->
      String.is_suffix name ~suffix:".sexp"
      && not (String.equal name "index.sexp"))
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun name -> load_entry (Filename.concat dir name))

(* One catalog row for a single variant of [entry]. Extracted from
   [build_index] to keep nesting shallow (named helper instead of a record
   literal three closures deep). *)
let _variant_row (entry : entry) (v : variant_record) : index_row =
  {
    config_hash = v.config_hash;
    base_scenario = entry.base_scenario;
    window_id = entry.window_id;
    verdict = entry.verdict;
    entry_slug = entry.slug;
  }

let build_index (entries : entry list) : index_row list =
  List.concat_map entries ~f:(fun entry ->
      List.map entry.variants ~f:(_variant_row entry))

let save_index ~dir (entries : entry list) : unit =
  let path = Filename.concat dir "index.sexp" in
  let rows = build_index entries in
  Sexp.save_hum path ([%sexp_of: index_row list] rows)

let lookup (rows : index_row list) ~config_hash ~base_scenario ~window_id :
    verdict option =
  List.find_map rows ~f:(fun row ->
      if
        String.equal row.config_hash config_hash
        && String.equal row.base_scenario base_scenario
        && String.equal row.window_id window_id
      then Some row.verdict
      else None)
