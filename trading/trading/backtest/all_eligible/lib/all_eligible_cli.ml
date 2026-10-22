(** CLI parsing and output/config resolution for the all-eligible runner. *)

open Core

type cli_args = {
  scenario_path : string;
  out_dir : string option;
  entry_dollars : float option;
  return_buckets : float list option;
  min_grade : Weinstein_types.grade option;
  grade_sweep : bool;
  config_overrides : Sexp.t list;
  warehouse_dir : string option;
}

let _usage () =
  String.concat ~sep:"\n"
    [
      "Usage: all_eligible_runner --scenario <path> [options]";
      "  --scenario <path>            Path to scenario sexp (required).";
      "  --out-dir <path>             Output dir (default: \
       dev/all_eligible/<name>/<UTC>/).";
      "  --entry-dollars <float>      Override entry-dollar sizing.";
      "  --return-buckets <csv>       Override return-bucket boundaries (e.g. \
       -0.5,0.0,0.5).";
      "  --min-grade <F|D|C|B|A|A+>   Cascade grade floor (default: C).";
      "  --grade-sweep                Run F/D/C/B/A as a sweep; emit one \
       subdir per grade plus a top-level cross-grade summary.";
      "  --snapshot-dir <warehouse>   Read bars from a pre-built snapshot \
       warehouse (its manifest.sexp) instead of building from CSV data/. Use \
       for broad universes (e.g. top-3000) the CSV store doesn't hold.";
      "  --config-overrides <sexp>    Extra config overrides (sexp list, \
       passthrough).";
    ]

let _fail_usage msg = failwith (msg ^ "\n" ^ _usage ())

let _parse_buckets s : float list =
  String.split s ~on:',' |> List.map ~f:String.strip
  |> List.filter ~f:(fun cell -> not (String.is_empty cell))
  |> List.map ~f:Float.of_string

let _parse_grade s : Weinstein_types.grade =
  match String.uppercase (String.strip s) with
  | "A+" | "APLUS" -> A_plus
  | "A" -> A
  | "B" -> B
  | "C" -> C
  | "D" -> D
  | "F" -> F
  | other ->
      _fail_usage
        (Printf.sprintf "--min-grade expects one of {F,D,C,B,A,A+}, got %s"
           other)

let _parse_overrides s : Sexp.t list =
  match Sexp.of_string s with
  | List items -> items
  | Atom _ ->
      _fail_usage
        "--config-overrides expects a sexp list, e.g. '((entry_dollars \
         5000.0))'"

let parse_argv argv =
  let init =
    {
      scenario_path = "";
      out_dir = None;
      entry_dollars = None;
      return_buckets = None;
      min_grade = None;
      grade_sweep = false;
      config_overrides = [];
      warehouse_dir = None;
    }
  in
  let rec loop acc = function
    | [] -> acc
    | "--scenario" :: v :: rest -> loop { acc with scenario_path = v } rest
    | "--out-dir" :: v :: rest -> loop { acc with out_dir = Some v } rest
    | "--entry-dollars" :: v :: rest ->
        loop { acc with entry_dollars = Some (Float.of_string v) } rest
    | "--return-buckets" :: v :: rest ->
        loop { acc with return_buckets = Some (_parse_buckets v) } rest
    | "--min-grade" :: v :: rest ->
        loop { acc with min_grade = Some (_parse_grade v) } rest
    | "--grade-sweep" :: rest -> loop { acc with grade_sweep = true } rest
    | "--snapshot-dir" :: v :: rest ->
        loop { acc with warehouse_dir = Some v } rest
    | "--config-overrides" :: v :: rest ->
        loop { acc with config_overrides = _parse_overrides v } rest
    | flag :: _ -> _fail_usage (Printf.sprintf "Unknown flag: %s" flag)
  in
  let args = Array.to_list argv |> List.tl |> Option.value ~default:[] in
  let parsed = loop init args in
  if String.is_empty parsed.scenario_path then
    _fail_usage "Missing required flag: --scenario"
  else parsed

(* ---------------------------------------------------------------- *)
(* Out-dir / config resolution                                        *)
(* ---------------------------------------------------------------- *)

(** Render [now] as a filesystem-safe UTC ISO timestamp, e.g.
    [2026-05-06T20-13-44Z]. Replaces colons (illegal on some filesystems) with
    hyphens. *)
let _utc_timestamp () : string =
  let now = Time_ns.now () in
  let s = Time_ns.to_string_iso8601_basic now ~zone:Time_float.Zone.utc in
  String.tr s ~target:':' ~replacement:'-'

let resolve_out_dir ~scenario_name (args : cli_args) : string =
  match args.out_dir with
  | Some d -> d
  | None ->
      let ts = _utc_timestamp () in
      Filename.concat (Filename.concat "dev/all_eligible" scenario_name) ts

let resolve_config (args : cli_args) : All_eligible.config =
  let base = All_eligible.default_config in
  let entry_dollars =
    Option.value args.entry_dollars ~default:base.entry_dollars
  in
  let return_buckets =
    Option.value args.return_buckets ~default:base.return_buckets
  in
  let min_grade = Option.value args.min_grade ~default:base.min_grade in
  { entry_dollars; return_buckets; min_grade }
