(** Rank walk-forward CV variants by Pareto frontier (Sharpe up, Calmar up,
    MaxDD% down) and report each variant's Deflated Sharpe Ratio (DSR).

    Pure consumer of artefacts already on disk:
    - [--aggregate <path>] — a {!Walk_forward.Walk_forward_types.aggregate} sexp
      (the same shape {!Walk_forward.Walk_forward_runner} writes to
      [aggregate.sexp]). Mandatory.
    - [--fold-actuals <path>] — a [Walk_forward_types.fold_actual list] sexp
      ([fold_actuals.sexp] from the runner). Optional; required for DSR.
    - [--baseline-label <label>] — header annotation; defaults to "baseline".
    - [--output <path>] — write markdown there; default stdout.

    DSR is per-variant: feeds the variant's [sharpe_ratio.mean] (from the
    aggregate) as the observed Sharpe, the variant's per-fold [total_return_pct]
    series (from fold_actuals) as the fold returns, and the across-variant
    Sharpe-mean variance as the best-of-N selection-bias correction. Variants
    with fewer than two non-NaN fold returns or zero return-variance are skipped
    (no DSR column for that row); the rendering treats missing labels as "n/a"
    per {!Walk_forward.Variant_ranking.render}.

    Gap C of [dev/plans/experiment-platform-2026-05-29.md]: every future verdict
    ranks via the same committed pipeline rather than an ad-hoc exe. *)

open Core
module T = Walk_forward.Walk_forward_types
module VR = Walk_forward.Variant_ranking
module DS = Backtest_stats.Deflated_sharpe

(* -------------- argument parsing -------------- *)

type cli_args = {
  aggregate_path : string;
  fold_actuals_path : string option;
  baseline_label : string;
  output_path : string option;
}

let _default_baseline_label = "baseline"

let _usage_msg =
  "Usage: rank_variants.exe --aggregate <aggregate.sexp> [--fold-actuals \
   <fold_actuals.sexp>] [--baseline-label <label>] [--output <path>]"

let _parse_args argv =
  let rec loop agg folds baseline out = function
    | [] -> (
        match agg with
        | Some a ->
            {
              aggregate_path = a;
              fold_actuals_path = folds;
              baseline_label =
                Option.value baseline ~default:_default_baseline_label;
              output_path = out;
            }
        | None ->
            eprintf "Error: --aggregate is required\n%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--aggregate" :: p :: rest -> loop (Some p) folds baseline out rest
    | "--fold-actuals" :: p :: rest -> loop agg (Some p) baseline out rest
    | "--baseline-label" :: l :: rest -> loop agg folds (Some l) out rest
    | "--output" :: p :: rest -> loop agg folds baseline (Some p) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None argv

(* -------------- input loading -------------- *)

(** Load a sexp file, exiting non-zero with a path-quoted message on any I/O or
    parse error. Both inputs go through this helper so the error shape is
    consistent. *)
let _load_sexp ~label ~path ~of_sexp =
  try
    let sexp = Sexp.load_sexp path in
    of_sexp sexp
  with
  | Sys_error msg ->
      eprintf "Error: cannot read %s %S: %s\n" label path msg;
      Stdlib.exit 1
  | Sexp.Of_sexp_error (exn, _) ->
      eprintf "Error: failed to parse %s %S: %s\n" label path
        (Exn.to_string exn);
      Stdlib.exit 1
  | exn ->
      eprintf "Error: failed to load %s %S: %s\n" label path (Exn.to_string exn);
      Stdlib.exit 1

let _load_aggregate path =
  _load_sexp ~label:"aggregate" ~path ~of_sexp:T.aggregate_of_sexp

let _load_fold_actuals path =
  _load_sexp ~label:"fold-actuals" ~path ~of_sexp:(fun sexp ->
      [%of_sexp: T.fold_actual list] sexp)

(* -------------- DSR computation -------------- *)

(** Minimum number of finite fold returns required to compute DSR (PSR's
    [sqrt (n_obs - 1)] term needs at least 2 observations). *)
let _min_fold_count = 2

(** Population variance of [xs] using a two-pass mean / sum-of-squares walk.
    Empty / single-element inputs return [0.0]; the caller filters those out
    earlier so this is defensive. *)
let _population_variance xs =
  match xs with
  | [] | [ _ ] -> 0.0
  | _ ->
      let n = List.length xs in
      let mean = List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n in
      let ss =
        List.fold xs ~init:0.0 ~f:(fun acc x ->
            let d = x -. mean in
            acc +. (d *. d))
      in
      ss /. Float.of_int n

(** Per-variant fold returns from [fold_actuals], filtering by [variant_label]
    and dropping NaN entries. *)
let _fold_returns_for ~variant_label fold_actuals =
  List.filter_map fold_actuals ~f:(fun (fa : T.fold_actual) ->
      if String.equal fa.variant_label variant_label then
        if Float.is_finite fa.total_return_pct then Some fa.total_return_pct
        else None
      else None)

type dsr_outcome =
  | Computed of float
  | Skipped of string  (** Reason string for the stderr note. *)

(** Compute DSR for one variant, or explain why we skipped it. *)
let _compute_dsr_one ~variant_label ~observed_sharpe ~fold_actuals ~n_trials
    ~sharpe_variance_across_trials =
  let fold_returns = _fold_returns_for ~variant_label fold_actuals in
  if List.length fold_returns < _min_fold_count then
    Skipped
      (sprintf "%s: only %d finite fold return(s); need at least %d"
         variant_label (List.length fold_returns) _min_fold_count)
  else if Float.( <= ) (_population_variance fold_returns) 0.0 then
    Skipped (sprintf "%s: zero variance across fold returns" variant_label)
  else
    try
      let dsr =
        DS.deflated_sharpe ~observed_sharpe ~fold_returns ~n_trials
          ~sharpe_variance_across_trials
      in
      Computed dsr
    with Invalid_argument msg -> Skipped (sprintf "%s: %s" variant_label msg)

(** Walk the aggregate's [stability] list, computing DSR for each variant and
    collecting both the assoc list passed to the renderer and a list of skip
    reasons surfaced on stderr. *)
let _build_dsr_table (aggregate : T.aggregate) fold_actuals =
  let stability = aggregate.stability in
  let n_trials = List.length stability in
  if n_trials < _min_fold_count then
    (* expected_max_sharpe needs n >= 2; if we have one variant, DSR is
       undefined for the whole table. *)
    ( [],
      [
        sprintf "n_trials = %d; need at least %d for DSR" n_trials
          _min_fold_count;
      ] )
  else
    let sharpe_means =
      List.map stability ~f:(fun s -> s.sharpe_ratio.mean)
      |> List.filter ~f:Float.is_finite
    in
    let sharpe_variance_across_trials = _population_variance sharpe_means in
    if Float.( <= ) sharpe_variance_across_trials 0.0 then
      ( [],
        [
          sprintf
            "Sharpe variance across %d variants is zero; DSR undefined for \
             every variant"
            n_trials;
        ] )
    else
      let dsrs, skips =
        List.fold stability ~init:([], [])
          ~f:(fun (acc_dsr, acc_skip) (s : T.variant_stability) ->
            match
              _compute_dsr_one ~variant_label:s.variant_label
                ~observed_sharpe:s.sharpe_ratio.mean ~fold_actuals ~n_trials
                ~sharpe_variance_across_trials
            with
            | Computed dsr -> ((s.variant_label, dsr) :: acc_dsr, acc_skip)
            | Skipped msg -> (acc_dsr, msg :: acc_skip))
      in
      (List.rev dsrs, List.rev skips)

(* -------------- output -------------- *)

let _render ~baseline_label ~ranking ~deflated_sharpe_by_label =
  let body = VR.render ranking ~deflated_sharpe_by_label in
  sprintf "# Variant ranking\n\nBaseline: %s\n\n%s\n" baseline_label body

let _write_output ~output_path md =
  match output_path with
  | None -> print_string md
  | Some path -> Out_channel.write_all path ~data:md

(* -------------- main -------------- *)

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let aggregate = _load_aggregate args.aggregate_path in
  let dsr_table, skips =
    match args.fold_actuals_path with
    | None -> ([], [])
    | Some path ->
        let fold_actuals = _load_fold_actuals path in
        _build_dsr_table aggregate fold_actuals
  in
  List.iter skips ~f:(fun msg ->
      eprintf "[rank_variants] skipped DSR — %s\n" msg);
  let ranking = VR.rank aggregate.stability in
  let md =
    _render ~baseline_label:args.baseline_label ~ranking
      ~deflated_sharpe_by_label:dsr_table
  in
  _write_output ~output_path:args.output_path md

let () = _main ()
