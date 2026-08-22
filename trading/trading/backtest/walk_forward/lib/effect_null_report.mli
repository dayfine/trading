(** Effect-vs-null reporting — the "Rule-4 table" automated.

    Every experiment writeup hand-builds the same table: per metric, the paired
    arm-vs-null gap, that metric's own null-noise band, the ratio between them,
    and whether the gap direction is consistent across salts. It is the binding
    constraint on every verdict and it is error-prone by hand — a glob that
    spanned two arms, a wrong join column, and a difference-of-means where a
    paired-within-salt difference was required all shipped in one week.

    This module is the pure core: parse scenario-result sexps into named
    metrics, pair arm against null {b by position} (salt {i i} with salt {i i}),
    compute each metric's own null band, and emit a verdict that refuses to
    overclaim. {!Effect_null_render} turns a report into the markdown a writeup
    pastes; [bin/effect_null_report.ml] is the thin CLI around both.

    Task A2-1 of [dev/status/arc-readiness.md] (Axis 2 — validation tooling). *)

open Core

type metrics = (string * float) list [@@deriving sexp]
(** One scenario result's numeric metrics, in file order. *)

type run_context = {
  universe_size : int option;
  start_date : string option;
  end_date : string option;
}
[@@deriving sexp]
(** The run-context fields that decide whether two results are comparable at
    all. Each is optional because the producing artefact may not carry it. *)

type context_check =
  | Verified  (** At least one field was comparable and every one matched. *)
  | Unverified of string
      (** No field was comparable on both sides — the caller should warn loudly
          rather than fail, since many committed results have no params beside
          them. *)
  | Mismatch of string
      (** A comparable field differed. The message names the field, both values,
          and why this is fatal. *)
[@@deriving sexp]

type verdict =
  | Pass
      (** Every pair's gap has the same sign {b and} every |gap| exceeds that
          metric's null band. *)
  | Inside_noise  (** A sign flip, or a gap that does not clear the band. *)
  | Not_judged
      (** The metric was marked directionless by the caller: reported, but no
          success/failure claim is made about it. *)
  | No_null_band
      (** No band could be estimated: a single arm/null pair, or a null whose
          values are identical across salts. A zero spread means the salt axis
          moved the null by nothing — the noise floor is {i unmeasured}, not
          zero, so calling any gap a PASS against it would be exactly the
          overclaim this tool exists to prevent. *)
[@@deriving sexp]

type metric_row = {
  metric : string;
  arm_values : float list;  (** Arm value per pair, in input order. *)
  null_values : float list;  (** Null value per pair, in input order. *)
  paired_gaps : float list;
      (** [arm_i - null_i] per pair — a within-salt difference, never a
          difference of pooled means. *)
  mean_gap : float;  (** Mean of {!paired_gaps}. *)
  null_band : float;
      (** The null set's own salt-to-salt spread, [max - min]; for a scalar set
          that is exactly the largest pairwise |gap|. [nan] — never [0.0] — when
          there is a single pair, so nothing downstream can read one observation
          as a measured noise floor of zero. *)
  ratio : float option;
      (** [|mean_gap| / null_band], or [None] when the band is zero or not
          finite. *)
  verdict : verdict;
}
[@@deriving sexp]

type report = { salt_count : int; rows : metric_row list; notes : string list }
[@@deriving sexp]
(** [rows] follow the metric order of the first arm file. [notes] are free-text
    caveats the caller wants carried into both renderings (e.g. an unverified
    run context). *)

val min_pairs_for_a_band : int
(** The fewest arm/null pairs from which a null band can be estimated at all.
    Below it every verdict is {!No_null_band}. *)

val parse_metrics : Sexp.t -> metrics Status.status_or
(** [parse_metrics sexp] reads a flat scenario-result sexp — a list of
    [(name value)] pairs, the shape [actual.sexp] carries. Pairs whose value
    parses as a float become metrics, in file order; every other shape (nested
    lists, non-numeric atoms such as [(crashed false)] or [(crash_message "")])
    is dropped, because a result mixes numeric metrics with bookkeeping fields
    and only the former are comparable. Returns [Error] for a bare atom or when
    no numeric pair is present. *)

val parse_context : Sexp.t -> run_context
(** [parse_context sexp] extracts the run context from a [params.sexp] (fields
    at the top level) or from a scenario spec (dates nested inside a
    [(period ((start_date ..) (end_date ..)))] block); both shapes are accepted
    so the checker works against whichever artefact a run committed. Absent or
    unparseable fields become [None] — this function never fails. *)

val check_context : arm:run_context -> null:run_context -> context_check
(** [check_context ~arm ~null] compares [universe_size], [start_date] and
    [end_date]. A field counts only when present on both sides. Any comparable
    field that differs yields {!Mismatch}: a null measured at a different scale
    or over a different window is not this arm's null, and importing it is the
    error the guardrail exists to stop. When nothing is comparable the result is
    {!Unverified} — the caller warns, it does not fail. *)

val build :
  arm:metrics list ->
  null:metrics list ->
  no_direction:string list ->
  report Status.status_or
(** [build ~arm ~null ~no_direction] pairs the two lists {b by position} and
    builds one {!metric_row} per metric of the first arm file, in that file's
    order.

    Metrics named in [no_direction] are reported with verdict {!Not_judged}: a
    metric with no better/worse direction (trade counts, holding days) must not
    be handed a success/failure claim.

    Returns [Error] when either list is empty, when the two lists have different
    lengths (positional pairing has no meaning then), or when any file's metric
    set differs from the first arm file's — the message names the missing and
    extra metrics rather than silently intersecting, because a silent
    intersection is how a metric quietly disappears from a verdict table.

    [notes] on the returned report is empty; callers add their own. *)

(** Rendering lives in {!Effect_null_render}. *)
