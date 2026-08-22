open Core
module R = Effect_null_report

let verdict_label = function
  | R.Pass -> "PASS"
  | R.Inside_noise -> "INSIDE-NOISE"
  | R.Not_judged -> "not judged (directionless)"
  | R.No_null_band -> "NO-BAND"

(** A non-finite cell is "n/a", never "0.0000": an unmeasured band and a
    measured band of zero must not read the same. *)
let _fmt f = if Float.is_finite f then sprintf "%.4f" f else "n/a"

let _fmt_signed f = if Float.is_finite f then sprintf "%+.4f" f else "n/a"

let _row_markdown (row : R.metric_row) =
  sprintf "| %s | %s | %s | %s | %s | %s |" row.metric
    (_fmt_signed row.mean_gap)
    (String.concat ~sep:", " (List.map row.paired_gaps ~f:_fmt_signed))
    (_fmt row.null_band)
    (Option.value_map row.ratio ~default:"n/a" ~f:_fmt)
    (verdict_label row.verdict)

let _single_pair_note =
  "Single arm/null pair: the null's own salt-to-salt spread is not measurable, \
   so **no noise claim is possible** — gaps are reported without a PASS / \
   INSIDE-NOISE judgment."

let _preamble (report : R.report) =
  let extra =
    if report.salt_count < R.min_pairs_for_a_band then [ _single_pair_note ]
    else []
  in
  List.map (report.notes @ extra) ~f:(fun n -> sprintf "> %s\n" n)

let _header ~arm_label ~null_label (report : R.report) =
  [
    "# Effect vs null\n\n";
    sprintf "Arm: `%s` vs null: `%s`; %d pair(s), matched by position.\n\n"
      arm_label null_label report.salt_count;
  ]

let _table_head =
  [
    "\n\
     | metric | mean paired gap | per-pair gaps | null band | ratio | verdict |\n";
    "|---|---|---|---|---|---|\n";
  ]

let markdown ~arm_label ~null_label (report : R.report) =
  String.concat
    (_header ~arm_label ~null_label report
    @ _preamble report @ _table_head
    @ List.map report.rows ~f:(fun r -> _row_markdown r ^ "\n"))
