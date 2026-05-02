open Core
module Metric_type = Trading_simulation_types.Metric_types.Metric_type

type metric_stats = {
  name : string;
  values : float list;
  median : float;
  p25 : float;
  p75 : float;
  std : float;
  min : float;
  max : float;
}
[@@deriving sexp_of]

type t = {
  fuzz_spec_raw : string;
  variant_labels : string list;
  metric_stats : metric_stats list;
}
[@@deriving sexp_of]

(** Linearly interpolate between [sorted.(lo)] and [sorted.(hi)] at the
    fractional position [h - lo]. Pulled out so [_percentile_sorted] reads
    flatly. *)
let _interpolate_at sorted ~lo ~hi ~h =
  if lo = hi then sorted.(lo)
  else
    let frac = h -. Float.of_int lo in
    sorted.(lo) +. (frac *. (sorted.(hi) -. sorted.(lo)))

(** Type-7 linear-interpolation percentile (R [quantile(type=7)] / NumPy
    [np.percentile(method='linear')]). [q] is in [0, 1]. Operates on a
    pre-sorted array so the caller can amortise the sort across multiple
    percentile calls. *)
let _percentile_sorted ~q sorted =
  let n = Array.length sorted in
  match n with
  | 0 -> 0.0
  | 1 -> sorted.(0)
  | _ ->
      let h = q *. Float.of_int (n - 1) in
      let lo = Float.iround_down_exn h in
      let hi = Float.iround_up_exn h in
      _interpolate_at sorted ~lo ~hi ~h

let _mean xs =
  match xs with
  | [] -> 0.0
  | _ ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

(** Sample standard deviation (Bessel-corrected: divides by n-1). [0.0] for
    fewer than 2 points — the population std is meaningless on a single draw. *)
let _sample_std xs =
  let n = List.length xs in
  if n < 2 then 0.0
  else
    let m = _mean xs in
    let sq_sum =
      List.fold xs ~init:0.0 ~f:(fun acc x ->
          let d = x -. m in
          acc +. (d *. d))
    in
    Float.sqrt (sq_sum /. Float.of_int (n - 1))

(** Quantile fractions for the standard 25/50/75 split. Named here so the
    magic-number linter doesn't flag the call sites — these are the
    domain-conventional p25/p50/p75 cuts used by every distribution-summary
    table downstream. *)
let _q_p25 = 0.25

let _q_median = 0.5
let _q_p75 = 0.75

let _stats_of_values ~name values =
  let sorted = List.sort values ~compare:Float.compare |> Array.of_list in
  let n = Array.length sorted in
  let min = if n = 0 then 0.0 else sorted.(0) in
  let max = if n = 0 then 0.0 else sorted.(n - 1) in
  {
    name;
    values;
    median = _percentile_sorted ~q:_q_median sorted;
    p25 = _percentile_sorted ~q:_q_p25 sorted;
    p75 = _percentile_sorted ~q:_q_p75 sorted;
    std = _sample_std values;
    min;
    max;
  }

(** Pull a single metric's values out of every labelled summary that publishes
    it. Variants where the summary omits the metric are silently dropped — the
    resulting list length may be less than [n_variants]. *)
let _values_for_metric labelled_summaries mt =
  List.filter_map labelled_summaries ~f:(fun (_, s) ->
      Map.find s.Summary.metrics mt)

(** Build a single per-metric stats row, or [None] if the metric is absent from
    every variant. *)
let _stats_for_metric labelled_summaries mt =
  let values = _values_for_metric labelled_summaries mt in
  if List.is_empty values then None
  else Some (_stats_of_values ~name:(Comparison.metric_label mt) values)

(** Walk [Comparison.all_metric_types] in stable order; for each metric pull the
    value out of every summary that publishes it. Rows with no values across any
    variant are filtered out — they'd just be noise. *)
let _build_metric_stats labelled_summaries =
  List.filter_map Comparison.all_metric_types
    ~f:(_stats_for_metric labelled_summaries)

let compute ~fuzz_spec_raw labelled_summaries =
  {
    fuzz_spec_raw;
    variant_labels = List.map labelled_summaries ~f:fst;
    metric_stats = _build_metric_stats labelled_summaries;
  }

(* ----- Sexp rendering ----- *)

let _float_atom f = Sexp.Atom (sprintf "%.4f" f)
let _pair name value = Sexp.List [ Sexp.Atom name; value ]

let _values_block values =
  _pair "values" (Sexp.List (List.map values ~f:_float_atom))

let _metric_stats_body (s : metric_stats) =
  Sexp.List
    [
      _pair "median" (_float_atom s.median);
      _pair "p25" (_float_atom s.p25);
      _pair "p75" (_float_atom s.p75);
      _pair "std" (_float_atom s.std);
      _pair "min" (_float_atom s.min);
      _pair "max" (_float_atom s.max);
      _values_block s.values;
    ]

let _metric_stats_to_sexp (s : metric_stats) =
  Sexp.List [ Sexp.Atom s.name; _metric_stats_body s ]

let _labels_block (t : t) =
  _pair "variant_labels"
    (Sexp.List (List.map t.variant_labels ~f:(fun l -> Sexp.Atom l)))

let _metric_stats_block (t : t) =
  _pair "metric_stats"
    (Sexp.List (List.map t.metric_stats ~f:_metric_stats_to_sexp))

let to_sexp t =
  Sexp.List
    [
      _pair "fuzz_spec_raw" (Sexp.Atom t.fuzz_spec_raw);
      _labels_block t;
      _metric_stats_block t;
    ]

(* ----- Markdown rendering ----- *)

let _format_float f = sprintf "%.4f" f

let _markdown_header (t : t) =
  let n = List.length t.variant_labels in
  sprintf
    "# Fuzz distribution\n\n\
     - Spec: `%s`\n\
     - Variants: %d\n\
     - Variant labels: %s\n\n"
    t.fuzz_spec_raw n
    (String.concat ~sep:", " t.variant_labels)

let _markdown_table_row (s : metric_stats) =
  sprintf "| %s | %s | %s | %s | %s | %s | %s | %d |\n" s.name
    (_format_float s.median) (_format_float s.p25) (_format_float s.p75)
    (_format_float s.std) (_format_float s.min) (_format_float s.max)
    (List.length s.values)

let _markdown_table (t : t) =
  let header =
    "| Metric | Median | p25 | p75 | Std | Min | Max | N |\n\
     |---|---|---|---|---|---|---|---|\n"
  in
  let rows = List.map t.metric_stats ~f:_markdown_table_row |> String.concat in
  "## Per-metric distribution\n\n" ^ header ^ rows ^ "\n"

let to_markdown t = _markdown_header t ^ _markdown_table t
let write_sexp ~output_path t = Sexp.save_hum output_path (to_sexp t)

let write_markdown ~output_path t =
  Out_channel.write_all output_path ~data:(to_markdown t)
