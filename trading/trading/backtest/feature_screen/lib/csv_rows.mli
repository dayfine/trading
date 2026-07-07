(** Parsed rows of the all-eligible [trades.csv].

    Consumes the 19-column CSV written by
    [All_eligible_runner.write_trades_csv]. Only the columns the multivariate
    screen needs are retained; the rest (symbol, side, prices, sizing) are
    parsed for column-position validation but largely discarded. Feature cells
    may be empty in the source CSV — those map to [None]. *)

type row = {
  signal_date : Core.Date.t;  (** Entry Friday — drives the era split. *)
  return_pct : float;
      (** Counterfactual trade return; the regression target. *)
  cascade_score : int;  (** Cascade grade score at signal; always present. *)
  passes_macro : bool;  (** Whether the macro gate passed; always present. *)
  rs_value : float option;
      (** Relative-strength value; [None] when uncomputed. *)
  rs_trend : string option;
      (** RS-trend category (sexp atom); [None] if absent. *)
  volume_ratio : float option;  (** Breakout volume ratio; [None] if no bar. *)
  weeks_advancing : int option;
      (** Stage-2 weeks advancing; [None] if not S2. *)
  stage2_late : bool option;
      (** Stage-2 MA-deceleration flag; [None] if not S2. *)
  resistance_quality : string option;
      (** Overhead-resistance category (sexp atom); [None] if absent. *)
}
[@@deriving sexp_of]

val expected_header : string
(** The exact header line the parser validates against, mirroring
    [All_eligible_runner._csv_header]. *)

val parse_rows : string list -> (row list, string) result
(** [parse_rows lines] parses whole CSV file contents (header + data rows).
    Returns [Error msg] if the header does not match [expected_header] or any
    data row has the wrong column count / an unparseable required field. Empty
    optional cells parse to [None]. A trailing empty line is ignored. *)

val concat_files : (string * string list) list -> (row list, string) result
(** [concat_files named_contents] parses and concatenates several trades-CSV
    files (each [(name, lines)]); the header is validated per file. Used to pool
    grade-sweep cells. [name] is only used for error messages. *)
