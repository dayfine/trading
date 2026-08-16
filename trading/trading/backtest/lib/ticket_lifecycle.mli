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
          confirmed ⇒ the F5 rule {i would} eject. Whether it actually did is
          {!fill_volume_outcome}'s job, not this constructor's: the audit
          population is deliberately wider than the eject population (see
          {!fill_volume_check}). Each measured quantity is carried so
          near-misses are rankable; a [None] means that one branch alone lacked
          history. *)
  | No_verdict
      (** {b Held without a verdict}: neither branch had enough history, so
          {!Volume.classify_breakout} returned [None] and the runner held —
          fail-soft, "absence of evidence is not an unconfirmed breakout".
          Recording this is the qc-behavioral #2267 recommendation: without it
          the held population cannot be split into "confirmed" and "never
          judged", and an arm's eject rate carries an unmeasured residual. *)
[@@deriving sexp]

(** What the F5 eject path {b actually did} with the position on the tick the
    verdict above was recorded. Read off the tick's real [volume_eject]
    transitions and skip set — never inferred from the verdict, because the two
    populations differ. *)
type fill_volume_outcome =
  | Ejected
      (** A [volume_eject] [TriggerExit] was emitted for this position. *)
  | Skipped_other_exit
      (** {!Weinstein_strategy.Volume_eject_runner.update} never considered this
          position: another exit channel (stop, Stage-3, laggard, force-liq,
          liquidity, extension) had already claimed it this tick. The audit
          surface still evaluated it, because the fill's volume verdict is a
          property of the {i fill}, independent of what else befell the position
          that day — and this cohort (weak-volume breakout that stops out in
          week 0/1) is exactly what the plan's §5 prediction 4 measures. *)
  | Held
      (** Considered and not ejected — either confirmed, or [No_verdict]'s
          fail-soft hold. *)
[@@deriving sexp]

type fill_volume_check = {
  verdict : fill_volume_verdict;  (** What §4.2 said about the fill week. *)
  outcome : fill_volume_outcome;  (** What the run did about it. *)
}
[@@deriving sexp]
(** The F5 at-fill record: a verdict {b paired with} an outcome.

    They are one record rather than two optional fields so that a verdict
    without its outcome is unrepresentable. That matters because [Unconfirmed]
    does {b not} imply [Ejected]: an [Unconfirmed] row carrying
    [Skipped_other_exit] is a fill whose volume failed §4.2 but whose position
    was already leaving via another channel. Counting [Unconfirmed] rows as
    ejects would overstate the eject rate by exactly that cohort; with both
    halves recorded, a ladder-v4 reader can compute "unconfirmed fills" and
    "actual ejects" separately and measure their overlap. *)

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
          {!Trade_context} still falls back to matching it against fill dates
          when a round-trip carries no position id). Naming the placement
          instant explicitly gives the two age fields below a documented anchor
          that a later change to [entry_date]'s meaning cannot silently
          invalidate. *)
  ticket_age_weeks_at_cancel : int option; [@sexp.option]
      (** Whole weeks the ticket rested before it was {b cancelled} — set by
          {!Trade_audit.record_transitions} from the [CancelEntry] transition's
          date minus {!placement_date}. {b Unbounded}, and the column F2's TTL
          analysis should read: a TTL cancel is by construction the multi-week
          case ([entry_order_ttl_weeks] is also in weeks, so the units line up
          without conversion).

          [None] when the ticket did not resolve by cancellation — it filled, or
          it was still resting at end-of-run. *)
  cancel_reason : string option; [@sexp.option]
      (** The [CancelEntry] transition's own reason token, persisted verbatim.
          Always [Some] exactly when {!ticket_age_weeks_at_cancel} is, and read
          together with it: the age says {i how long} the ticket rested, this
          says {i what killed it}. Three tokens exist —
          {!Trading_simulation.Cancel_handler.portfolio_rejection_reason}
          ([entry_fill_rejected_by_portfolio]) and
          {!Weinstein_strategy.Entry_ticket_ttl}'s [entry_ticket_ttl_expired] /
          [entry_ticket_requalification_failed].

          The distinction is load-bearing, not cosmetic. The two TTL tokens are
          {b decisions} the strategy took; the rejection token is an
          {b accident of capital timing} — a ticket that triggered, filled at
          the engine, and was then refused because the book could not fund it
          (dev/notes/ticket-death-on-cash-2026-08-16.md). Averaging a cancel-age
          column across both populations mixes a policy with a failure. *)
  ticket_age_weeks_at_fill : int option; [@sexp.option]
      (** Whole weeks the ticket rested before it {b filled} — set by
          {!Execution_faithfulness.enrich} from the matched round-trip's
          entry-fill date minus {!placement_date}.

          {b Unbounded} since the {!Trade_context} join became position-id
          keyed. Before that it was structurally capped at one week — the join
          could only reach back 7 days from the fill, so a longer-resting ticket
          was not matched at all and this column could only read [0] or [1]. Any
          analysis of this field over a run produced before that fix is reading
          the join window, not the resting-time distribution.

          Kept separate from {!ticket_age_weeks_at_cancel} so the two resolution
          modes stay distinguishable: a reader cannot average one column and get
          the other's statistic wearing a fill-inclusive label. The two
          resolutions are mutually exclusive, so at most one of the pair is ever
          [Some].

          [None] also when the enrichment pass did not run at all (raw collector
          output, e.g. in unit tests). *)
  fill_volume : fill_volume_check option; [@sexp.option]
      (** The F5 at-fill §4.2 verdict {b paired with what the run did about it},
          or [None] when no at-fill check ran for this entry at all — the
          default config ([volume_confirm_at_fill = false]), a short, or a
          ticket that never filled. Distinct from
          [Some { verdict = No_verdict; _ }], which means the check {i did} run
          and could not judge. *)
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
    the resolutions are merged in later by {!resolve} / {!with_fill_age}. *)

val age_weeks : placed:Date.t -> resolved:Date.t -> int
(** Whole weeks between placement and resolution. Clamped at [0]: a resolution
    dated before its own placement is not a negative age. *)

val age_weeks_from : t option -> resolved:Date.t -> int option
(** {!age_weeks} against a record's own {!placement_date}. [None] in ⇒ [None]
    out: a pre-PR-5 row has no placement anchor, and no lifecycle to hold the
    answer either. *)

val resolve :
  t option ->
  fill_volume:fill_volume_check option ->
  cancel_age_weeks:int option ->
  cancel_reason:string option ->
  t option
(** Fold the collector-side observations (the F5 fill-week check and the cancel
    age + reason) into a placement-time record. [None] in ⇒ [None] out: a
    [trade_audit.sexp] row written before PR-5 has no lifecycle to merge into
    and is never given one. Both arguments are [None] on a row whose ticket
    simply filled under an unarmed F5 config — the no-observation case, not a
    zero. Never touches {!ticket_age_weeks_at_fill}, which only the enrichment
    pass can know. *)

val with_fill_age : t option -> resolved:Date.t -> t option
(** Stamp only {!ticket_age_weeks_at_fill}, from [resolved] against the record's
    own {!placement_date}. Used by the fill-side enrichment, which learns the
    fill date after the collector has already been drained; an already-merged
    {!ticket_age_weeks_at_cancel} is left intact. [None] in ⇒ [None] out, same
    contract as {!resolve}. *)
