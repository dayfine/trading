(** Effect-vs-null report — the Rule-4 table an experiment writeup pastes.

    Consumes scenario-result [actual.sexp] files already on disk:

    - [--arm <a0.sexp[,a1.sexp,...]>] — the mechanism arm. Mandatory.
    - [--null <n0.sexp[,...]>] — the control. Mandatory. Paired with [--arm]
      {b by position} (salt {i i} against salt {i i}), so the two lists must be
      the same length.
    - [--no-direction <m1,m2>] — metrics with no better/worse direction; they
      are reported but never judged.
    - [--arm-params] / [--null-params] — run-context files ([params.sexp], or a
      scenario spec) parallel to the result lists. When omitted, a [params.sexp]
      sitting beside each result file is picked up automatically.
    - [--arm-label] / [--null-label] — header names. Default to the file paths.
    - [--sexp] — machine-readable output instead of markdown.
    - [--output <path>] — write there; default stdout.

    Guardrail: if the run contexts are comparable and differ on universe size or
    on the date window, the tool refuses (exit 1) rather than reporting a gap
    against a null that was never this arm's null. If no context is available on
    both sides it prints a loud WARNING and continues.

    Task A2-1 of [dev/status/arc-readiness.md]. *)

open Core
module R = Walk_forward.Effect_null_report
module Render = Walk_forward.Effect_null_render

type cli_args = {
  arm_paths : string list;
  null_paths : string list;
  arm_params : string list option;
  null_params : string list option;
  no_direction : string list;
  arm_label : string option;
  null_label : string option;
  sexp_output : bool;
  output_path : string option;
}

let _usage_msg =
  "Usage: effect_null_report.exe --arm <a.sexp[,a2.sexp,...]> --null \
   <n.sexp[,...]> [--arm-params <p[,p2]>] [--null-params <p[,p2]>] \
   [--no-direction <m1,m2>] [--arm-label <s>] [--null-label <s>] [--sexp] \
   [--output <path>]"

let _die msg =
  eprintf "Error: %s\n%s\n" msg _usage_msg;
  Stdlib.exit 1

let _split_commas s =
  String.split s ~on:',' |> List.map ~f:String.strip
  |> List.filter ~f:(Fn.non String.is_empty)

let _empty_args =
  {
    arm_paths = [];
    null_paths = [];
    arm_params = None;
    null_params = None;
    no_direction = [];
    arm_label = None;
    null_label = None;
    sexp_output = false;
    output_path = None;
  }

let rec _parse_args acc = function
  | [] -> acc
  | "--arm" :: v :: rest ->
      _parse_args { acc with arm_paths = _split_commas v } rest
  | "--null" :: v :: rest ->
      _parse_args { acc with null_paths = _split_commas v } rest
  | "--arm-params" :: v :: rest ->
      _parse_args { acc with arm_params = Some (_split_commas v) } rest
  | "--null-params" :: v :: rest ->
      _parse_args { acc with null_params = Some (_split_commas v) } rest
  | "--no-direction" :: v :: rest ->
      _parse_args { acc with no_direction = _split_commas v } rest
  | "--arm-label" :: v :: rest ->
      _parse_args { acc with arm_label = Some v } rest
  | "--null-label" :: v :: rest ->
      _parse_args { acc with null_label = Some v } rest
  | "--sexp" :: rest -> _parse_args { acc with sexp_output = true } rest
  | "--output" :: v :: rest ->
      _parse_args { acc with output_path = Some v } rest
  | ("--help" | "-h") :: _ ->
      printf "%s\n" _usage_msg;
      Stdlib.exit 0
  | unknown :: _ -> _die (sprintf "unknown or incomplete argument %S" unknown)

(* -------------- loading -------------- *)

let _load_sexp path =
  try Sexp.load_sexp path
  with exn -> _die (sprintf "cannot read %S: %s" path (Exn.to_string exn))

(** Context files are hand-written specs as often as generated [params.sexp]s,
    and a mis-terminated leading comment can leave a spec holding several
    top-level sexps. Flatten them into one list so field lookup still works —
    strictness here would reject a file whose context fields are perfectly
    readable. Result files stay on the strict single-sexp path above. *)
let _load_context_sexp path =
  try
    match Sexp.load_sexps path with
    | [ single ] -> single
    | many ->
        Sexp.List
          (List.concat_map many ~f:(function
            | Sexp.List entries -> entries
            | Sexp.Atom _ as a -> [ a ]))
  with exn -> _die (sprintf "cannot read %S: %s" path (Exn.to_string exn))

let _load_metrics path =
  match R.parse_metrics (_load_sexp path) with
  | Ok m -> m
  | Error err -> _die (sprintf "%s: %s" path err.Status.message)

(** Params for one result file: the explicit path at the same position when
    [--*-params] was given, else a [params.sexp] sitting beside the result. *)
let _params_for ~explicit ~index result_path =
  match explicit with
  | Some paths -> List.nth paths index
  | None ->
      let beside =
        Filename.concat (Filename.dirname result_path) "params.sexp"
      in
      if Stdlib.Sys.file_exists beside then Some beside else None

let _contexts ~explicit paths =
  List.mapi paths ~f:(fun index path ->
      Option.map (_params_for ~explicit ~index path) ~f:(fun p ->
          R.parse_context (_load_context_sexp p)))

(* -------------- guardrail -------------- *)

(** Fold the per-pair context checks into one outcome: any mismatch is fatal;
    otherwise the report is verified if at least one pair could be compared. *)
let _check_all_contexts ~arm_contexts ~null_contexts =
  let checks =
    List.map2_exn arm_contexts null_contexts ~f:(fun arm null ->
        match (arm, null) with
        | Some arm, Some null -> R.check_context ~arm ~null
        | _ -> R.Unverified "no run context available for this pair")
  in
  match
    List.find_map checks ~f:(function R.Mismatch m -> Some m | _ -> None)
  with
  | Some msg -> Error msg
  | None ->
      if List.exists checks ~f:(function R.Verified -> true | _ -> false) then
        Ok None
      else
        Ok
          (Some
             "WARNING: run context could not be verified — no universe_size / \
              date window available on both sides. A null does not transfer \
              across scales or universes; confirm by hand that arm and null \
              ran on the same universe and window.")

(* -------------- output -------------- *)

let _write ~output_path text =
  match output_path with
  | None -> print_string text
  | Some path -> Out_channel.write_all path ~data:text

let _render args report =
  if args.sexp_output then Sexp.to_string_hum (R.sexp_of_report report) ^ "\n"
  else
    let label given paths =
      Option.value given ~default:(String.concat ~sep:"," paths)
    in
    Render.markdown
      ~arm_label:(label args.arm_label args.arm_paths)
      ~null_label:(label args.null_label args.null_paths)
      report

(* -------------- main -------------- *)

let _main () =
  let args =
    Sys.get_argv () |> Array.to_list |> List.tl_exn |> _parse_args _empty_args
  in
  if List.is_empty args.arm_paths || List.is_empty args.null_paths then
    _die "--arm and --null are both required";
  if List.length args.arm_paths <> List.length args.null_paths then
    _die
      "--arm and --null are paired by position; give the same number of files";
  let warning =
    match
      _check_all_contexts
        ~arm_contexts:(_contexts ~explicit:args.arm_params args.arm_paths)
        ~null_contexts:(_contexts ~explicit:args.null_params args.null_paths)
    with
    | Ok w -> w
    | Error msg ->
        eprintf "Error: refusing to compare — %s\n" msg;
        Stdlib.exit 1
  in
  Option.iter warning ~f:(fun w -> eprintf "[effect_null_report] %s\n" w);
  match
    R.build
      ~arm:(List.map args.arm_paths ~f:_load_metrics)
      ~null:(List.map args.null_paths ~f:_load_metrics)
      ~no_direction:args.no_direction
  with
  | Error err -> _die err.Status.message
  | Ok report ->
      let report = { report with notes = Option.to_list warning } in
      _write ~output_path:args.output_path (_render args report)

let () = _main ()
