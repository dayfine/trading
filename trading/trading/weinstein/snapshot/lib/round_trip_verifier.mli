(** Round-trip verifier for split / dividend handling.

    Replays a known historical corporate action (split or cash dividend) and
    asserts that the system's behaviour matches book-keeping rules:

    - {b Adjusted-close continuity.} For pre-split bars, the EODHD
      [adjusted_close] back-rolled by the split factor must reconcile with the
      raw [close_price] within tolerance.
    - {b Position carry-over.} A held position present before the split must
      still be present after, with quantity scaled by [factor] and per-share
      entry / stop prices divided by [factor].
    - {b Cost-basis preservation.}
      [quantity_pre × entry_price_pre = quantity_post × entry_price_post] for
      the held position.
    - {b No phantom picks.} The post-split candidate set must be a subset of the
      pre-split set — no symbol becomes a candidate purely because of
      split-induced numerical drift.
    - {b Cash-dividend bookkeeping.} For dividend scenarios:
      [cash_post = cash_pre + quantity × div_per_share]; quantity unchanged.

    The verifier is a pure function. It returns a {!Round_trip_result.t} value
    enumerating every check that ran with PASS / FAIL state plus a
    human-readable detail string — never raises and never aborts on the first
    failure. Callers can then assert on the result with the standard matchers.

    {1 Why a separate verifier (not just snapshot equality)?}

    Snapshot equality would require pinning every numeric field exactly. Real
    historical bars have small floating-point noise across data vendor versions
    and re-runs of the back-roll computation. The verifier expresses the
    {b mathematical relationships} the system must preserve across a corporate
    action, so the test fails {e only} when those relationships break — not when
    the underlying close_price drifts by 1 cent between data refreshes. *)

open Core

type held_lot = {
  symbol : string;
  quantity : float;
      (** Share count BEFORE the corporate action. Multiplied by [factor] for
          the post-split expectation. *)
  entry_price : float;  (** Per-share cost basis BEFORE the corporate action. *)
}
[@@deriving show, eq]
(** Per-position lot context the verifier needs to check carry-over invariants.
    [Weekly_snapshot.held_position] stores [stop] and [status] but not
    [quantity] / [entry_price] (those live in the runtime portfolio, not the
    snapshot). The verifier therefore takes them as a separate input and
    cross-checks against the snapshot's [stop] field. *)

type check_status = Pass | Fail [@@deriving show, eq]

type check = {
  name : string;
      (** Stable identifier for the check (e.g. ["adjusted_close_continuity"]).
          Used by CI logs and the verify CLI to label PASS / FAIL outcomes. *)
  status : check_status;
  detail : string;
      (** One-line human-readable explanation. On FAIL, must include the
          observed and expected values so the failure is reproducible from the
          log line alone. *)
}
[@@deriving show, eq]

module Round_trip_result : sig
  type t = { checks : check list } [@@deriving show, eq]

  val all_pass : t -> bool
  (** [all_pass r] is [true] when every check is [Pass]. Empty result counts as
      pass — the caller is responsible for adding at least one check. *)

  val failures : t -> check list
  (** Returns only the failing checks, preserving order. *)
end

val verify_split_round_trip :
  symbol:string ->
  split_date:Date.t ->
  factor:float ->
  bars:Types.Daily_price.t list ->
  pre_split_lot:held_lot ->
  pick_pre_split:Weekly_snapshot.t ->
  pick_post_split:Weekly_snapshot.t ->
  ?adjusted_close_tolerance:float ->
  unit ->
  Round_trip_result.t
(** Run all split-related checks for one scenario.

    - [bars] must include at least one pre-split and one post-split bar.
    - [pre_split_lot] is the position the strategy was holding going into the
      split. Its [symbol] need not equal the split [symbol] — the verifier uses
      [symbol] argument to locate the held position in both snapshots.
    - [adjusted_close_tolerance] is the relative tolerance for the
      [adjusted_close × factor ≈ close_price] check. Defaults to [1e-3] (0.1%) —
      tight enough to catch a missed adjustment, loose enough to tolerate vendor
      rounding. *)

val verify_dividend_round_trip :
  symbol:string ->
  ex_date:Date.t ->
  amount_per_share:float ->
  pre_lot:held_lot ->
  pick_pre:Weekly_snapshot.t ->
  pick_post:Weekly_snapshot.t ->
  cash_pre:float ->
  cash_post:float ->
  ?cash_tolerance:float ->
  unit ->
  Round_trip_result.t
(** Run all cash-dividend checks for one scenario.

    Asserts:
    - [cash_post ≈ cash_pre + quantity × amount_per_share] (within
      [cash_tolerance], default [1e-6]).
    - The held position's quantity is unchanged across the dividend.
    - The held position is still present in the post snapshot, with the same
      [stop] (dividends do not adjust stops in this convention). *)
