(** Inert-fraction metric over [Trade_audit.split_safe_basis].

    See [split_safe_metric.mli] for the API contract and for why the result is a
    variant rather than a float. *)

open Core

type tally = {
  flag_off : int;
  adjusted : int;
  raw_fallback : int;
  empty_window : int;
}
[@@deriving show, eq, sexp]

let empty_tally =
  { flag_off = 0; adjusted = 0; raw_fallback = 0; empty_window = 0 }

(* Exhaustive by construction: adding a fifth basis state makes this match
   incomplete, which is the point — a new state must be given an explicit place
   in the metric rather than silently joining a catch-all. *)
let _count_one tally (basis : Trade_audit.split_safe_basis) =
  match basis with
  | Trade_audit.Flag_off -> { tally with flag_off = tally.flag_off + 1 }
  | Trade_audit.Adjusted -> { tally with adjusted = tally.adjusted + 1 }
  | Trade_audit.Raw_fallback ->
      { tally with raw_fallback = tally.raw_fallback + 1 }
  | Trade_audit.Empty_window ->
      { tally with empty_window = tally.empty_window + 1 }

let tally_of_bases bases = List.fold bases ~init:empty_tally ~f:_count_one

type inertness = Inert_fraction of float | Not_exercised of tally
[@@deriving show, eq]

(* [Empty_window] and [Flag_off] appear in neither term; see the .mli for why
   each is excluded for its own reason. When the remaining two are both zero the
   ratio is undefined, and returning it as a number — 0.0, or nan — is exactly
   the failure this type exists to prevent, so the tally is handed back instead
   for the caller to read the cause off. *)
let inertness_of_tally tally =
  let denominator = tally.raw_fallback + tally.adjusted in
  if denominator = 0 then Not_exercised tally
  else
    Inert_fraction (Float.of_int tally.raw_fallback /. Float.of_int denominator)
