(** Design-matrix construction for the feature screen.

    Turns parsed {!Csv_rows.row}s into a numeric [n × p] design matrix:
    continuous features are z-standardised (coefficients then read as return per
    1 SD), booleans stay 0/1, and categoricals are one-hot encoded with the
    first OBSERVED category dropped as the reference level. Only observed
    non-reference levels get a dummy column (unobserved levels would be all-zero
    and make the design rank-deficient). A complete-case filter drops any row
    missing a selected feature; per-feature None coverage is reported over the
    full (pre-filter) population. *)

type feature =
  | Cascade_score  (** Continuous. *)
  | Rs_value  (** Continuous. *)
  | Volume_ratio  (** Continuous. *)
  | Weeks_advancing  (** Continuous. *)
  | Passes_macro  (** Boolean 0/1. *)
  | Stage2_late  (** Boolean 0/1. *)
  | Rs_trend  (** Categorical, one-hot (ref = [Bullish_crossover]). *)
  | Resistance_quality  (** Categorical, one-hot (ref = [Virgin_territory]). *)
[@@deriving sexp_of, eq]

type kind = Continuous | Boolean | Categorical of string list

type design = {
  x : float array array;
      (** [n × p] rows, column 0 is the intercept (all ones). *)
  y : float array;  (** [return_pct] per complete-case row. *)
  win : float array;  (** [1.0] if [return_pct > 0] else [0.0]. *)
  column_names : string list;  (** [p] labels, ["intercept"] first. *)
  n_complete : int;  (** Complete-case row count. *)
}

type coverage = {
  feature : string;  (** Feature name. *)
  present : int;  (** Rows where the feature is non-[None]. *)
  total : int;  (** Total rows considered. *)
}

val all_features : feature list
(** Canonical order used when [--features] is omitted. *)

val feature_name : feature -> string
(** Lowercase identifier, matching the CSV column name. *)

val feature_of_string : string -> feature option
(** Parse a [--features] token (case-insensitive) to a feature. *)

val feature_kind : feature -> kind
(** Modelling kind; [Categorical] carries its full category set in canonical
    order. The dropped reference is the first of these that is observed in the
    data (see {!build}). *)

val build :
  features:feature list ->
  rows:Csv_rows.row list ->
  (design * coverage list, string) result
(** [build ~features ~rows] computes coverage over all [rows], complete-case
    filters, and assembles the standardised one-hot design matrix. [Error] when
    no complete-case rows remain. *)

val era_bounds : (string * int * int) list
(** The fixed era split as [(label, min_year, max_year)] inclusive: 2000-2008 /
    2009-2017 / 2018-2026. *)

val eras : Csv_rows.row list -> (string * Csv_rows.row list) list
(** [eras rows] partitions [rows] by [signal_date] year into {!era_bounds}
    (empty eras are retained so the caller can report them). *)
