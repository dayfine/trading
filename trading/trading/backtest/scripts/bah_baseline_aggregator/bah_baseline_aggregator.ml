(** [bah_baseline_aggregator] CLI — produce a BAH baseline aggregate.sexp for a
    walk-forward window spec.

    Implements M4 T4.3 of
    [dev/plans/tuning-research-driven-program-v2-2026-05-25.md]. See
    {!Bah_baseline_aggregator_lib} for the math + variant-label contract.

    {1 Usage}

    {[
      bah_baseline_aggregator \
        --symbol SPY \
        --spec trading/test_data/walk_forward/cell_e_full_history_28fold_2026_05_25.sexp \
        --data-dir /workspaces/trading-1/data \
        --variant-label cell-E \
        --out dev/experiments/bayesian-production-sweep-2026-05-25/baseline_aggregate_v7_spy.sexp
    ]}

    The [--variant-label] must equal the walk-forward spec's [baseline_label] so
    the BO scorer's [_lookup_stability] succeeds (see lib's mli). *)

open Core
module Lib = Bah_baseline_aggregator_lib
module Wf_types = Walk_forward.Walk_forward_types
module Wf_spec = Walk_forward.Spec
module Window_spec = Walk_forward.Window_spec

(* ---------- I/O ---------- *)

let _ok_or_fail ~ctx ~symbol = function
  | Ok v -> v
  | Error err ->
      failwithf "bah_baseline_aggregator: %s failed for %s: %s" ctx symbol
        (Status.show err) ()

let _load_prices ~data_dir ~symbol : Types.Daily_price.t list =
  let storage =
    _ok_or_fail ~ctx:"storage create" ~symbol
      (Csv.Csv_storage.create ~data_dir symbol)
  in
  _ok_or_fail ~ctx:"load" ~symbol (Csv.Csv_storage.get storage ())

let _load_window_spec ~spec_path : Window_spec.t =
  let spec = Wf_spec.load spec_path in
  spec.window_spec

let _write_aggregate ~out_path (agg : Wf_types.aggregate) : unit =
  let sexp = Wf_types.sexp_of_aggregate agg in
  Out_channel.write_all out_path ~data:(Sexp.to_string_hum sexp ^ "\n")

(* ---------- CLI ---------- *)

type cli_args = {
  symbol : string;
  spec_path : string;
  data_dir : string;
  variant_label : string;
  out_path : string;
}

let _usage =
  "bah_baseline_aggregator --symbol SPY --spec PATH --data-dir PATH \
   --variant-label cell-E --out PATH"

let _parse_args argv =
  let rec loop sym spec data label out = function
    | [] -> (sym, spec, data, label, out)
    | "--symbol" :: v :: rest -> loop (Some v) spec data label out rest
    | "--spec" :: v :: rest -> loop sym (Some v) data label out rest
    | "--data-dir" :: v :: rest -> loop sym spec (Some v) label out rest
    | "--variant-label" :: v :: rest -> loop sym spec data (Some v) out rest
    | "--out" :: v :: rest -> loop sym spec data label (Some v) rest
    | "--help" :: _ | "-h" :: _ ->
        printf "%s\n" _usage;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage;
        Stdlib.exit 1
  in
  match loop None None None None None argv with
  | ( Some symbol,
      Some spec_path,
      Some data_dir,
      Some variant_label,
      Some out_path ) ->
      { symbol; spec_path; data_dir; variant_label; out_path }
  | _ ->
      eprintf "Error: missing required argument\n%s\n" _usage;
      Stdlib.exit 1

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let prices =
    _load_prices ~data_dir:(Fpath.v args.data_dir) ~symbol:args.symbol
  in
  let window_spec = _load_window_spec ~spec_path:args.spec_path in
  let agg =
    Lib.compute_bah_aggregate ~prices ~spec:window_spec
      ~label:args.variant_label
  in
  _write_aggregate ~out_path:args.out_path agg;
  eprintf "[bah_baseline_aggregator] symbol=%s folds=%d label=%S wrote %s\n%!"
    args.symbol agg.fold_count args.variant_label args.out_path

let () = _main ()
