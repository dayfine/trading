(** Durable CLI that constructs a well-formed {!Experiment_ledger.entry} from a
    walk-forward aggregate and writes it to the append-only ledger
    ([dev/experiments/_ledger/]).

    Closes P2.2 of the population-search apparatus
    ([dev/plans/population-search-2026-05-31.md]): every ledger entry to date
    was hand-authored sexp or written by a throwaway exe rebuilt repeatedly.
    This is the committed writer so future experiments stop hand-authoring sexp.

    Inputs:
    - Scalar metadata via flags ([--date], [--slug], [--hypothesis],
      [--base-scenario], [--window-id], [--baseline-label], [--verdict],
      [--notes], [--out-dir]).
    - [--aggregate <path>] — the {!Walk_forward.Walk_forward_types.aggregate}
      sexp the run produced (same artefact [rank_variants.exe] consumes). The
      per-variant labels + cross-fold metric means come from here.
    - [--variant-spec <path>] (optional) — the walk-forward {!Walk_forward.Spec}
      sexp that produced the run. When supplied, each variant's [config_hash] is
      computed from its override blob (via the auto-included baseline + expanded
      matrix) so the recorded hashes match the ledger's dedup key. When omitted,
      hashes are [""].

    Pairs with [rank_variants.exe]: that ranks the surface (Pareto + DSR), this
    records the resulting verdict. Both are pure consumers of the same on-disk
    aggregate. *)

open Core
module T = Walk_forward.Walk_forward_types
module EL = Experiment_ledger
module B = Ledger_entry_builder

(* -------------- argument parsing -------------- *)

type cli_args = {
  aggregate_path : string;
  variant_spec_path : string option;
  out_dir : string;
  metadata : B.metadata;
}

let _default_baseline_label = "baseline"
let _default_out_dir = "dev/experiments/_ledger"

let _usage_msg =
  "Usage: write_ledger_entry.exe --date <YYYY-MM-DD> --slug <slug> \
   --hypothesis <text> --base-scenario <path> --window-id <id> --verdict \
   <accept|reject|inconclusive> --aggregate <aggregate.sexp> [--variant-spec \
   <spec.sexp>] [--baseline-label <label>] [--notes <text>] [--out-dir <dir>]"

let _fail msg =
  eprintf "Error: %s\n%s\n" msg _usage_msg;
  Stdlib.exit 1

let _parse_verdict = function
  | "accept" | "Accept" -> EL.Accept
  | "reject" | "Reject" -> EL.Reject
  | "inconclusive" | "Inconclusive" -> EL.Inconclusive
  | other ->
      _fail (sprintf "unknown --verdict %S (accept|reject|inconclusive)" other)

(* Accumulator for the raw flag strings before they are validated into
   [cli_args]. Every field optional so a missing required flag is reported with a
   precise name rather than a partial-record exception. *)
type raw = {
  date : string option;
  slug : string option;
  hypothesis : string option;
  base_scenario : string option;
  window_id : string option;
  baseline_label : string option;
  verdict : string option;
  notes : string option;
  aggregate : string option;
  variant_spec : string option;
  out_dir : string option;
}

let _empty_raw =
  {
    date = None;
    slug = None;
    hypothesis = None;
    base_scenario = None;
    window_id = None;
    baseline_label = None;
    verdict = None;
    notes = None;
    aggregate = None;
    variant_spec = None;
    out_dir = None;
  }

let _require name = function
  | Some v -> v
  | None -> _fail (name ^ " is required")

let _finalize (r : raw) : cli_args =
  let metadata : B.metadata =
    {
      date = _require "--date" r.date;
      slug = _require "--slug" r.slug;
      hypothesis = _require "--hypothesis" r.hypothesis;
      base_scenario = _require "--base-scenario" r.base_scenario;
      window_id = _require "--window-id" r.window_id;
      baseline_label =
        Option.value r.baseline_label ~default:_default_baseline_label;
      verdict = _parse_verdict (_require "--verdict" r.verdict);
      notes = Option.value r.notes ~default:"";
    }
  in
  {
    aggregate_path = _require "--aggregate" r.aggregate;
    variant_spec_path = r.variant_spec;
    out_dir = Option.value r.out_dir ~default:_default_out_dir;
    metadata;
  }

let rec _accumulate (r : raw) = function
  | [] -> r
  | "--date" :: v :: rest -> _accumulate { r with date = Some v } rest
  | "--slug" :: v :: rest -> _accumulate { r with slug = Some v } rest
  | "--hypothesis" :: v :: rest ->
      _accumulate { r with hypothesis = Some v } rest
  | "--base-scenario" :: v :: rest ->
      _accumulate { r with base_scenario = Some v } rest
  | "--window-id" :: v :: rest -> _accumulate { r with window_id = Some v } rest
  | "--baseline-label" :: v :: rest ->
      _accumulate { r with baseline_label = Some v } rest
  | "--verdict" :: v :: rest -> _accumulate { r with verdict = Some v } rest
  | "--notes" :: v :: rest -> _accumulate { r with notes = Some v } rest
  | "--aggregate" :: v :: rest -> _accumulate { r with aggregate = Some v } rest
  | "--variant-spec" :: v :: rest ->
      _accumulate { r with variant_spec = Some v } rest
  | "--out-dir" :: v :: rest -> _accumulate { r with out_dir = Some v } rest
  | ("--help" | "-h") :: _ ->
      printf "%s\n" _usage_msg;
      Stdlib.exit 0
  | unknown :: _ -> _fail (sprintf "unknown argument %S" unknown)

let _parse_args argv = _finalize (_accumulate _empty_raw argv)

(* -------------- input loading -------------- *)

let _load_aggregate path : T.aggregate =
  try Sexp.load_sexp path |> T.aggregate_of_sexp with
  | Sys_error msg -> _fail (sprintf "cannot read aggregate %S: %s" path msg)
  | exn ->
      _fail
        (sprintf "failed to parse aggregate %S: %s" path (Exn.to_string exn))

(* [label -> config_hash] from the spec's resolved variant list (auto-included
   baseline + expanded matrix). A missing spec yields the empty map, so
   [config_hash_for] returns [""] for every label. *)
let _config_hash_for path_opt : string -> string =
  match path_opt with
  | None -> fun _ -> ""
  | Some path ->
      let spec =
        try Walk_forward.Spec.load path with
        | Sys_error msg ->
            _fail (sprintf "cannot read variant-spec %S: %s" path msg)
        | exn ->
            _fail
              (sprintf "failed to load variant-spec %S: %s" path
                 (Exn.to_string exn))
      in
      let pairs =
        List.map spec.variants
          ~f:(fun (v : Walk_forward.Walk_forward_runner.variant) ->
            (v.label, v.overrides))
      in
      let table = B.hash_map_of_variants pairs in
      fun label -> Option.value (Hashtbl.find table label) ~default:""

(* -------------- main -------------- *)

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let aggregate = _load_aggregate args.aggregate_path in
  let config_hash_for = _config_hash_for args.variant_spec_path in
  let entry =
    B.build_entry ~metadata:args.metadata ~config_hash_for aggregate
  in
  EL.save_entry ~dir:args.out_dir entry;
  printf "Wrote ledger entry: %s\n"
    (Filename.concat args.out_dir (sprintf "%s-%s.sexp" entry.date entry.slug))

let () = _main ()
