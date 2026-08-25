open Core
module Scenario = Scenario_lib.Scenario

type deviation = { field : string; golden : string; live : string }
type finding = Undeclared_deviation of deviation | Stale_declaration of string

type spec_report = {
  spec_path : string;
  skipped_reason : string option;
  findings : finding list;
}

(* The comparison base. [universe] / [index_symbol] are not reachable from a
   scenario's [config_overrides], so whatever we pass here lands identically on
   both sides of the diff and cancels. *)
let _base_index_symbol = "SPY"

let _base_config () =
  Weinstein_strategy.default_config ~universe:[]
    ~index_symbol:_base_index_symbol

(* Renderings longer than this are elided — a whole nested config record is
   thousands of characters and would bury the message. *)
let _max_rendered_chars = 160

let _render sexp =
  let s = Sexp.to_string sexp in
  if String.length s <= _max_rendered_chars then s
  else String.prefix s _max_rendered_chars ^ "..."

(* [(key, value)] pairs of a record's derived sexp. Non-record sexps (an atom, a
   bare list) yield [[]], which the callers treat as "not decomposable". *)
let _assoc_of_sexp = function
  | Sexp.List fields ->
      List.filter_map fields ~f:(function
        | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
        | _ -> None)
  | Sexp.Atom _ -> []

let _lookup assoc key = List.Assoc.find assoc ~equal:String.equal key

(* Fields present in either side whose values differ. Used both for the
   top-level diff and, one level down, to narrow a nested-record deviation to
   its differing leaves. *)
let _differing_keys left right =
  List.map left ~f:fst @ List.map right ~f:fst
  |> List.dedup_and_sort ~compare:String.compare
  |> List.filter ~f:(fun k ->
      not (Option.equal Sexp.equal (_lookup left k) (_lookup right k)))

(* [(key value)] for [key] if [assoc] has it, so a narrowed rendering keeps the
   same shape as the record it came from. *)
let _keyed_entry assoc key =
  Option.map (_lookup assoc key) ~f:(fun v -> Sexp.List [ Sexp.Atom key; v ])

(* Render one side of a deviation. When both sides decompose into records, keep
   only the leaves that actually differ so the message names the knob. *)
let _render_side ~self ~other =
  let self_assoc = _assoc_of_sexp self and other_assoc = _assoc_of_sexp other in
  if List.is_empty self_assoc || List.is_empty other_assoc then _render self
  else
    let differing = _differing_keys self_assoc other_assoc in
    _render (Sexp.List (List.filter_map differing ~f:(_keyed_entry self_assoc)))

let _field_sexp assoc field =
  Option.value (_lookup assoc field) ~default:(Sexp.List [])

let _deviation ~golden_assoc ~live_assoc field =
  let gv = _field_sexp golden_assoc field
  and lv = _field_sexp live_assoc field in
  {
    field;
    golden = _render_side ~self:gv ~other:lv;
    live = _render_side ~self:lv ~other:gv;
  }

let diff_configs ~golden ~live =
  let g = _assoc_of_sexp (Weinstein_strategy.sexp_of_config golden) in
  let l = _assoc_of_sexp (Weinstein_strategy.sexp_of_config live) in
  List.map (_differing_keys g l) ~f:(_deviation ~golden_assoc:g ~live_assoc:l)

let live_config ~overrides_path =
  let overlays =
    try Sexp.load_sexps overrides_path
    with exn ->
      failwithf "Failed to load live config overrides from %s: %s"
        overrides_path (Exn.to_string exn) ()
  in
  Backtest.Overlay_validator.apply_overrides (_base_config ()) overlays

let _declared_field_name spec_path = function
  | Sexp.List (Sexp.Atom field :: _) -> field
  | entry ->
      failwithf
        "%s: malformed deviates_from_live entry %s (expected (<field> \
         \"<reason>\"))"
        spec_path (Sexp.to_string entry) ()

(* Top-level [(key rest)] pairs of the raw spec sexp. Read directly rather than
   through {!Scenario.t}, which drops [deviates_from_live] via
   [@@sexp.allow_extra_fields]. *)
let _spec_fields spec_path =
  match Sexp.load_sexp spec_path with
  | Sexp.List fields ->
      List.filter_map fields ~f:(function
        | Sexp.List (Sexp.Atom k :: rest) -> Some (k, rest)
        | _ -> None)
  | Sexp.Atom _ -> failwithf "%s: scenario spec is not a record" spec_path ()

let declared_deviations spec_path =
  match _lookup (_spec_fields spec_path) "deviates_from_live" with
  | None -> []
  | Some [ Sexp.List entries ] ->
      List.map entries ~f:(_declared_field_name spec_path)
  | Some _ ->
      failwithf
        "%s: deviates_from_live must be a list of (<field> \"<reason>\")"
        spec_path ()

let _findings_for ~deviations ~declared =
  let is_declared field = List.mem declared field ~equal:String.equal in
  let differs field =
    List.exists deviations ~f:(fun d -> String.equal d.field field)
  in
  List.filter_map deviations ~f:(fun d ->
      if is_declared d.field then None else Some (Undeclared_deviation d))
  @ List.filter_map declared ~f:(fun field ->
      if differs field then None else Some (Stale_declaration field))

let _weinstein_report ~live ~spec_path (scenario : Scenario.t) =
  let golden =
    Backtest.Overlay_validator.apply_overrides (_base_config ())
      scenario.config_overrides
  in
  let deviations = diff_configs ~golden ~live in
  let declared = declared_deviations spec_path in
  {
    spec_path;
    skipped_reason = None;
    findings = _findings_for ~deviations ~declared;
  }

let _skipped_report ~spec_path strategy =
  {
    spec_path;
    skipped_reason =
      Some
        (sprintf "strategy %s has no Weinstein config to compare"
           (Backtest.Strategy_choice.name strategy));
    findings = [];
  }

let check_spec ~live spec_path =
  let scenario = Scenario.load spec_path in
  match scenario.strategy with
  | Backtest.Strategy_choice.Weinstein ->
      _weinstein_report ~live ~spec_path scenario
  | other -> _skipped_report ~spec_path other

let _specs_in_dir dir =
  if not (Stdlib.Sys.file_exists dir && Stdlib.Sys.is_directory dir) then
    failwithf "golden directory not found: %s" dir ()
  else
    Stdlib.Sys.readdir dir |> Array.to_list
    |> List.filter ~f:(String.is_suffix ~suffix:".sexp")
    |> List.map ~f:(Filename.concat dir)
    |> List.sort ~compare:String.compare

let check_dirs ~live dirs =
  List.concat_map dirs ~f:_specs_in_dir |> List.map ~f:(check_spec ~live)

let _render_finding spec_path = function
  | Undeclared_deviation d ->
      sprintf "%s: undeclared deviation %s (golden=%s live=%s)" spec_path
        d.field d.golden d.live
  | Stale_declaration field ->
      sprintf
        "%s: stale declaration %s (declared in deviates_from_live but matches \
         live)"
        spec_path field

let failure_count reports =
  List.sum (module Int) reports ~f:(fun r -> List.length r.findings)

let render_report reports =
  let lines =
    List.concat_map reports ~f:(fun r ->
        List.map r.findings ~f:(_render_finding r.spec_path))
  in
  let skipped =
    List.count reports ~f:(fun r -> Option.is_some r.skipped_reason)
  in
  let summary =
    sprintf "%d spec(s) checked, %d skipped, %d finding(s)"
      (List.length reports) skipped (failure_count reports)
  in
  if List.is_empty lines then sprintf "OK: %s" summary
  else String.concat ~sep:"\n" (lines @ [ sprintf "FAIL: %s" summary ])
