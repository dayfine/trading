(** Parser + variant generator for the [--fuzz <param>=<center>±<delta>:<n>] CLI
    flag.

    [Fuzz_spec] turns a single string spec into [n] concrete variants, each of
    which the runner executes as an independent backtest. The N runs together
    surface metric distribution stats (median, p25/p75, std, range) — the core
    insight is that a single backtest result is one draw from a noisy
    distribution; jittering an input parameter lets us see the spread.

    Two value kinds are supported:

    - {b Date}: spec like ["start_date=2019-05-01±5w:11"]. Delta units are [d]
      (days), [w] (weeks = 7 days), [m] (months — uses [Date.add_months], so
      end-of-month is clamped per Core's semantics). Generates N dates evenly
      spaced across [center - delta .. center + delta].

    - {b Numeric}: spec like ["stops_config.initial_stop_buffer=1.05±0.02:11"].
      Generates N floats evenly spaced across
      [center - delta .. center + delta].

    The key path uses the same dotted syntax as {!Config_override}; for date
    specs the key path is meta-routed (see {!variant} comment) — currently the
    only recognised date key is ["start_date"].

    Spacing: for [n=1] returns just the centre. For [n>1] uses [n] inclusive
    points so [n=11] emits centre-5*step, centre-4*step, ..., centre+5*step
    where [step = delta / 5]. Distance from centre is symmetric. *)

open Core

(** Variant payload produced for a single fuzz point. The shape is an algebraic
    sum because the runner needs to know whether to substitute the start_date
    positional or to inject a partial-config sexp into the override list. *)
type variant_value =
  | V_date of Date.t  (** Date variant; replaces the run's [start_date]. *)
  | V_float of float
      (** Numeric variant; injected into [overrides] as a partial-config sexp
          via {!Config_override.parse_to_sexp}. *)
[@@deriving sexp_of]

type variant = {
  index : int;
      (** 1-based ordinal across the N variants — matches the
          [variants/var-001/] subdir naming used by the runner. *)
  label : string;
      (** Short stable label for the variant value (e.g. ["2019-04-26"] or
          ["1.030"]). Used in distribution markdown rendering and as the subdir
          suffix when the runner writes per-variant artefacts. *)
  key_path : string;
      (** Original dotted key path from the spec (e.g. ["start_date"] or
          ["stops_config.initial_stop_buffer"]). The runner uses this to decide
          between date substitution vs override injection. *)
  value : variant_value;
}
[@@deriving sexp_of]

type t = {
  raw_spec : string;
      (** The spec string as passed on the command line — echoed into
          [experiment.sexp] for reproducibility. *)
  key_path : string;  (** Dotted key path (matches every [variant.key_path]). *)
  n : int;  (** Number of variants generated (always [List.length variants]). *)
  variants : variant list;
      (** The materialised variants in ascending value order. [List.length = n];
          for [n >= 2] the head is [center - delta] and the tail is
          [center + delta]. *)
}
[@@deriving sexp_of]

val parse : string -> t Status.status_or
(** [parse spec] parses one [--fuzz] argument string and materialises every
    variant.

    Spec syntax: [<key.path>=<center>±<delta>:<n>] where:
    - [<key.path>] is dotted-key syntax (alphanumeric + underscore + dot)
    - [<center>] is either a [YYYY-MM-DD] date or a float
    - [<delta>] for date centers is [Nd] / [Nw] / [Nm] (positive integer); for
      float centers is a positive float
    - [<n>] is a positive integer (>= 1)

    The [±] character is the unicode code point U+00B1 (UTF-8 [\xC2\xB1]). Both
    [±] and the ASCII fallback [+/-] are accepted to keep the CLI
    keyboard-friendly.

    Returns [Error Invalid_argument] for malformed spec, mismatched value kinds
    (e.g. date center with float-style delta), or [n <= 0]. *)

val subdir_name : n:int -> index:int -> string
(** [subdir_name ~n ~index] returns ["var-N"] zero-padded to the width of [n]
    (e.g. [n=11, index=3] → ["var-03"]; [n=100, index=3] → ["var-003"]). The
    runner uses this to lay out [dev/experiments/<name>/variants/var-NN/]
    subdirs. *)
