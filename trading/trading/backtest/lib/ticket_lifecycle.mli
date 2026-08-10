(** Resting-entry-ticket lifecycle audit record — PR-5 of
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] (§4 PR-5 row, §3-F6).

    Under the asynchronous ticket model an entry is no longer one instant: the
    ticket is {b placed} on one Friday and {b fills} (or is cancelled) later.
    {!Trade_audit.entry_decision} recorded only the placement instant's
    analysis, so none of ladder-v4's §5 questions — how long tickets rested,
    which clock admitted them, whether the fill's volume was actually confirmed,
    is the §4.5 cohort where the monsters are — could be answered from
    [trade_audit.sexp].

    This module owns that sub-schema and the two resolution merges over it, the
    way {!Stop_log} owns [exit_trigger]: [Trade_audit] holds one
    [Ticket_lifecycle.t option] field and stays a collector.

    {b Capture only.} Every field is a read of a value the run already computed;
    nothing here gates, scores, or sizes anything. *)

open Core

(** The book §4.2 breakout-volume verdict the F5 at-fill check reached on an
    entry's {b fill} week. On-disk mirror of
    {!Weinstein_strategy.Volume_eject_runner}'s classification (via
    {!Volume.breakout_confirmation}), re-declared here rather than aliased for
    the same reason {!Trade_audit.stop_floor_kind} is: this is the persisted
    schema, and it should be free to evolve without that being a change to an
    analysis-layer type. {!Trade_audit_recorder} holds the total mapping.

    The four cases are what a ladder-v4 F5 arm must count separately — an eject
    rate alone conflates the last two: *)
type fill_volume_verdict =
  | Confirmed_spike of float
      (** §4.2 branch (a): the fill week's volume reached [strong_threshold] ×
          its prior-weeks average. The float is that multiple. Held. *)
  | Confirmed_buildup of float
      (** §4.2 branch (b): the 3–4-week build-up reached [strong_threshold] ×
          the preceding equally sized window, with some increase on the fill
          week. The float is that multiple. Held. *)
  | Unconfirmed of {
      spike_ratio : float option;
      buildup_multiple : float option;
    }
      (** Both branches were evaluated against real history and neither
          confirmed ⇒ the position was {b ejected} ([volume_eject]). Each
          measured quantity is carried so near-misses are rankable; a [None]
          means that one branch alone lacked history. *)
  | No_verdict
      (** {b Held without a verdict}: neither branch had enough history, so
          {!Volume.classify_breakout} returned [None] and the runner held —
          fail-soft, "absence of evidence is not an unconfirmed breakout".
          Recording this is the qc-behavioral #2267 recommendation: without it
          the held population cannot be split into "confirmed" and "never
          judged", and an arm's eject rate carries an unmeasured residual. *)
[@@deriving sexp]

type triple_confirmation = {
  breakout_volume_multiple : float option;
      (** §4.5 (1) volume explosion — the breakout bar's volume over its
          prior-weeks average. *)
  rs_zero_cross : bool;
      (** §4.5 (2) RS breakout — the RS line crossed from negative into positive
          territory ([Weinstein_types.Bullish_crossover]). [false] also when the
          candidate carried no RS analysis. *)
  in_base_advance_pct : float option;
      (** §4.5 (3) pre-breakout advance — the base's top over the base's floor,
          minus one. The book's accumulation signature is ≥ 40%
          ({!Weinstein_strategy.Entry_ticket_tags.book_min_in_base_advance_pct}).
      *)
}
[@@deriving sexp]
(** The three book §4.5 "big winner" signals measured on the placed ticket
    ([docs/design/weinstein-book-reference.md] §4.5: Anthony Industries,
    National Semiconductor, Blocker Energy).

    {b An audit feature, never a gate} (plan §3-F6). Captured on every placed
    ticket so ladder-v4 can ask whether the triple-confirmed cohort is where the
    outsized winners live — the book's own discriminator for exactly the
    wide-range population F3/F4 argue about. No strategy code reads it. *)

(** Which F1 admission clock admitted the candidate. On-disk mirror of
    {!Weinstein_strategy.Entry_freshness.basis}. *)
type entry_freshness_basis =
  | Ma_cross  (** Default clock: freshness counted from the MA cross. *)
  | Range_top_breakout
      (** Armed clock: freshness counted from the breakout above the ticket
          anchor — Weinstein §1's own Stage-2 start event. *)
[@@deriving sexp]

type t = {
  placement_date : Date.t;
      (** The tick on which the resting entry ticket was written — i.e. when the
          strategy emitted its [CreateEntering].

          Equal to [Trade_audit.entry_decision.entry_date] on every row this
          build writes, and recorded separately on purpose: [entry_date] is the
          row's join key and its name reads like a {i fill} date (indeed
          {!Trade_context} matches it to fills with a 7-day window). Naming the
          placement instant explicitly gives
          {!ticket_age_weeks_at_fill_or_cancel} a documented anchor that a later
          change to [entry_date]'s meaning cannot silently invalidate. *)
  ticket_age_weeks_at_fill_or_cancel : int option; [@sexp.option]
      (** Whole weeks the ticket rested before it resolved — the quantity F2's
          TTL analysis needs ([entry_order_ttl_weeks] is also in weeks, so the
          units line up without conversion). The two resolutions are mutually
          exclusive and both are recorded:

          - {b cancelled} — set by {!Trade_audit.record_transitions} from the
            [CancelEntry] transition's date minus {!placement_date}. Unbounded,
            and the resolution F2's TTL analysis actually reads: a TTL cancel is
            by construction the multi-week case.
          - {b filled} — set by {!Execution_faithfulness.enrich} from the
            matched round-trip's entry-fill date minus {!placement_date}.

          {b Ceiling on the FILLED side}: that enrichment joins through
          {!Trade_context}, whose fallback window is 7 days, so a fill more than
          a week after placement is not matched and the age stays [None] (as
          does [Trade_audit.audit_record.execution] — a pre-existing property of
          that join, not introduced here). Read a fill-side age as "0 or 1
          week", never as the resting-time distribution; use the cancel side, or
          [trades.csv]'s own entry date, for long rests.

          [None] means no resolution was observed
          {i in the artifacts this row was built from}: still resting at
          end-of-run, filled outside the join window, or the enrichment pass did
          not run (raw collector output, e.g. in unit tests). *)
  fill_volume : fill_volume_verdict option; [@sexp.option]
      (** The F5 at-fill §4.2 verdict, or [None] when no at-fill check ran for
          this entry at all — the default config
          ([volume_confirm_at_fill = false]), a short, or a ticket that never
          filled. Distinct from [Some No_verdict], which means the check {i did}
          run and could not judge. *)
  freshness_basis : entry_freshness_basis;
      (** F1: which clock admitted the candidate. *)
  sized_down_wide_stop : bool;
      (** F3: [true] when [stop_width_mode = Size_down] admitted this candidate
          past [max_stop_distance_pct] — the entry exists only because the §5.1
          drop was waived, and its share count is the risk-parity-shrunk one.
          Always [false] under the default [Drop_over_max]. #2258 deliberately
          left this on the strategy-internal [entry_meta]; PR-5 persists it. *)
  triple_confirmation : triple_confirmation;  (** F6: the §4.5 measurements. *)
}
[@@deriving sexp]
(** The lifecycle record carried by {!Trade_audit.entry_decision}. Written with
    the placement-time fields populated and the two resolution fields [None];
    the resolutions are merged in later by {!resolve} / {!with_age}. *)

val age_weeks : placed:Date.t -> resolved:Date.t -> int
(** Whole weeks between placement and resolution. Clamped at [0]: a resolution
    dated before its own placement is not a negative age. *)

val age_weeks_from : t option -> resolved:Date.t -> int option
(** {!age_weeks} against a record's own {!placement_date}. [None] in ⇒ [None]
    out: a pre-PR-5 row has no placement anchor, and no lifecycle to hold the
    answer either. *)

val resolve :
  t option ->
  fill_volume:fill_volume_verdict option ->
  age_weeks:int option ->
  t option
(** Fold the collector-side observations (the F5 fill-week verdict and the
    cancel age) into a placement-time record. [None] in ⇒ [None] out: a
    [trade_audit.sexp] row written before PR-5 has no lifecycle to merge into
    and is never given one. Both arguments are [None] on a row whose ticket
    simply filled under an unarmed F5 config — the no-observation case, not a
    zero. *)

val with_age : t option -> resolved:Date.t -> t option
(** Stamp only {!ticket_age_weeks_at_fill_or_cancel}, from [resolved] against
    the record's own {!placement_date}. Used by the fill-side enrichment, which
    learns the fill date after the collector has already been drained. [None] in
    ⇒ [None] out, same contract as {!resolve}. *)
