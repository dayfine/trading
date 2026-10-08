(** Decision-trail recorder: a callback bundle the strategy invokes at entry /
    exit decision sites.

    The strategy emits raw events containing the analysis values it has in scope
    at decision time ({!Screener.scored_candidate}, {!Macro.result},
    {!Stage.result}, etc.). The backtest layer wires concrete callbacks that
    construct a {!Backtest.Trade_audit.entry_decision} / [exit_decision] from
    the event and accumulates them into a [Trade_audit.t] collector.

    The strategy library does not depend on [Backtest] — this module exists
    precisely to keep that direction. The {!noop} default lets non-recording
    callers leave the audit unwired with zero overhead. *)

open Core

(** Why a candidate produced by the screener was not entered.

    Tagged at the strategy boundary where [_make_entry_transition] is called.
    The backtest-side recorder maps these into
    {!Backtest.Trade_audit.skip_reason}.

    {b Note}: only the four reasons the strategy can directly observe at the
    sizing/cash/short-cap gates land here. Screener-internal truncations
    ([Below_min_grade], [Top_n_cutoff], [Sector_concentration]) are not visible
    at this site — the screener already filtered the candidate before the
    strategy saw it. The audit's [alternatives_considered] field therefore
    enumerates only the rivals from the same screen call that the strategy
    actually considered for entry. *)
type skip_reason =
  | Insufficient_cash
  | Already_held
  | Sized_to_zero
  | Short_notional_cap
      (** G15 step 2: short candidate dropped because aggregate short notional
          would exceed [Portfolio_risk.config.max_short_notional_fraction] of
          portfolio value. Only emitted for [Short] candidates. *)
  | Stop_too_wide
      (** G15 step 3: candidate dropped because the support-floor-derived
          initial stop sits more than
          [Weinstein_stops.config.max_stop_distance_pct] from entry. Implements
          Weinstein book §5.1's "if a stop requires more than 15% risk → prefer
          other candidates" rule. The gate fires symmetrically on longs and
          shorts; both sides can see structurally wide initial stops when the
          recent counter-move floor is far from current price. *)
  | Sector_exposure_cap
      (** P1 2026-05-15: candidate dropped because admitting it would push the
          aggregate dollar exposure of the candidate's sector past
          [Portfolio_risk.config.max_sector_exposure_pct] of portfolio value.
          Only fires when the config option is [Some _]; default-off path is a
          no-op. Named sectors only — empty-string (unknown) bucket is exempt
          and its discipline comes from
          [Portfolio_risk.config.max_unknown_sector_positions]. *)
  | Long_exposure_cap
      (** P0b 2026-07-13: LONG candidate dropped because admitting it would push
          aggregate entry-price-denominated long notional past
          [Weinstein_strategy_config.config.max_long_exposure_pct_entry] of
          portfolio value. The working replacement for the dead
          [Portfolio_risk.max_long_exposure_pct]. Only fires when the config
          field is [> 0.0] (default [0.0] => [Float.infinity] cap => no-op).
          Only emitted for [Long] candidates. *)
  | No_structural_stop
      (** Investor-preset gate: candidate dropped because its initial stop is
          the automatic-percentage fallback
          ([stop_floor_kind = Buffer_fallback]) rather than a structural support
          floor / resistance ceiling. Only fires when
          [Weinstein_strategy_config.config.require_structural_stop] is [true]
          (default [false] => never emitted). Book Ch. 6: "investors should
          never use automatic percentages". Both sides. *)
  | Share_class_held
      (** #3015: LONG candidate dropped because another share class of the same
          issuer ([Share_class_map]; e.g. GOOG / GOOGL) already has an open or
          pending long. Only fires when
          [Weinstein_strategy_config.config.max_one_share_class_per_issuer] is
          [true] (default [false] => never emitted). *)

type alternative_input = {
  candidate : Screener.scored_candidate;
  reason : skip_reason;
}
(** A candidate that scored at the same screen call as the chosen one but was
    not entered. *)

(** What the entry walk did with one top-N candidate on a screening Friday
    (#3139): [Placed] when it wrote the entry ticket, else the reason it was
    passed over. *)
type walk_outcome = Placed | Skipped of skip_reason

type walk_decision = {
  ranked : Screener.scored_candidate;
  outcome : walk_outcome;
}
(** One row of the weekly decision record: a top-N candidate the entry walk
    classified, with its one outcome. *)

(** Whether the installed initial stop sat on a real support floor (or short:
    resistance ceiling) derived from bar history, or fell back to the
    fixed-buffer proxy. Mirrors {!Backtest.Trade_audit.stop_floor_kind}. *)
type stop_floor_kind = Support_floor | Buffer_fallback

type split_safe_basis = Weinstein_stops.split_safe_basis =
  | Flag_off
  | Adjusted
  | Raw_fallback
  | Empty_window
      (** Which price basis the entry's support-floor scan ran on. Aliased from
          the stops layer rather than re-declared (unlike {!stop_floor_kind},
          which predates the strategy library's dependency on
          [weinstein_trading.stops]) so the audit tag and the scan cannot drift
          apart; the constructors are re-exported so downstream recorders can
          match on them without depending on the stops library. See
          {!Weinstein_stops.split_safe_basis} for why three states are needed.
      *)

type stop_move_event = {
  position_id : string;
      (** The held position whose stop moved — joins to
          [entry_event.position_id] and [Stop_log.stop_info.position_id]. *)
  symbol : string;
  date : Date.t;  (** The bar on which the stop state machine moved it. *)
  stop_level : float;
      (** The new level now resting in the strategy's stop state — the level the
          next bar's trigger check enforces. *)
}
(** A stop-level move that {b no transition carries}.

    The stops pass reports most moves as an [UpdateRiskParams] adjust, but
    [Weinstein_stops.update]'s [Entered_tightening] event moves the stop onto
    the tightened candidate without one ([Stop_transitions.of_stop_event] maps
    only [Stop_raised] to an adjust). The moved level is still enforced — the
    trigger check reads the stop state, not [risk_params] — so only the
    per-trade stop log missed it (issue #2974). This event is that log's feed.

    Observability only: emitting it changes no transition, and it is never
    produced for a split rescale ([Stops_split_runner] runs before the
    before/after comparison) or for a move an adjust transition already reports.

    Declared ahead of the other event records on purpose: they share the
    [position_id] / [symbol] / [date] labels, and an unannotated label resolves
    to the {e last} type declaring it, so declaring this one first leaves every
    existing unannotated access resolving as before. *)

type entry_event = {
  position_id : string;
      (** Position id assigned at entry — matches the [Position.transition] this
          event is recorded alongside, and [Stop_log.stop_info.position_id] /
          [Backtest.Trade_audit.entry_decision.position_id]. *)
  candidate : Screener.scored_candidate;
      (** The chosen candidate. Carries [analysis], [sector], [side], [score],
          [grade], [rationale], [suggested_entry], [suggested_stop], [risk_pct].
      *)
  macro : Macro.result;
      (** Macro snapshot computed by [_run_screen] this Friday. *)
  current_date : Date.t;
  close_at_decision : float option;
      (** Most recent close from [bar_reader] at the moment the entry was
          constructed — the price the strategy actually saw, independent of
          which entry basis ([suggested_entry] vs close) the config anchors the
          ticket at. [None] when [bar_reader] had no bars for the symbol.
          E-provenance telemetry (entry-ticket right-basis plan, 2026-08-08):
          lets the audit compare [candidate.suggested_entry] against the
          decision-time close without re-reading raw bars. *)
  adjusted_close_at_decision : float option;
      (** The same bar's [adjusted_close] — the basis the stage classifier's MA
          ([candidate.analysis.stage.ma_value]) is computed on. Pair it, not the
          RAW [close_at_decision], with the MA: across a later split the raw
          close sits a whole split factor away from the MA (issue #2973, NVDA
          2021-04-23: raw 610.61, adjusted 15.21, MA 13.67). Audit-only; [None]
          exactly when [close_at_decision] is [None]. *)
  installed_stop : float;
      (** Output of
          [Weinstein_stops.compute_initial_stop_with_floor_with_callbacks]'s
          stop level after the buffer is applied. *)
  stop_floor_kind : stop_floor_kind;
      (** Whether [installed_stop] sat on a real support floor or fell back. *)
  split_safe_basis : split_safe_basis;
      (** F5 telemetry: which price basis the floor scan for this entry ran on.
          [Raw_fallback] means [config.split_safe_floors] was on but the window
          could not be rescaled, so the scan silently produced the flag-off
          answer — a condition that is invisible in [installed_stop] alone.
          Aggregated over a run's entries this gives the {e inert fraction} of a
          [split_safe_floors] walk-forward arm, which must be known before the
          mechanism is promoted. *)
  shares : int;
      (** From [Portfolio_risk.compute_position_size] — round-share count
          actually ordered. *)
  initial_position_value : float;
      (** [shares * suggested_entry] — dollar exposure at entry. *)
  initial_risk_dollars : float;
      (** [|suggested_entry - installed_stop| * shares] — dollar risk to stop.
      *)
  sized_down_wide_stop : bool;
      (** F3 audit tag: [config.stop_width_mode = Size_down] admitted this
          candidate even though its structural stop sits further than
          [stops_config.max_stop_distance_pct] from entry, so the entry exists
          only because the §5.1 drop was waived and its share count is the
          risk-parity-shrunk one. Always [false] under the default
          [Drop_over_max] (such candidates are dropped, never entered). Carried
          straight from {!Entry_audit_capture.entry_meta.sized_down_wide_stop} —
          #2258 deliberately deferred persisting it to the PR-5 audit-fields
          step. *)
  entry_anchor : Screener.entry_anchor_kind;
      (** #3074 / #3089: which arm anchored the ticket's level. Equals
          {!Screener.entry_anchor_kind}[ candidate] except under
          [freeze_entry_at_first_breakout] (default off), where it is the arm
          {!Entry_freeze} pinned together with the frozen [E] — the arm of the
          week the level was set, not the current week's (see
          {!Entry_freeze.anchor_kind}). *)
  freshness_basis : Entry_freshness.basis;
      (** F1: which admission clock was in force when the candidate was
          analysed, recovered from the analysis by
          {!Entry_ticket_tags.freshness_basis_of_analysis}. *)
  triple_confirmation : Entry_ticket_tags.triple_confirmation;
      (** F6: the three book §4.5 "big winner" signals measured at placement.
          Capture only — nothing gates on it. *)
  alternatives : alternative_input list;
      (** Rivals from the same screen call that were not entered. *)
}
(** Event captured at entry-decision time. *)

(** What the F5 eject path did with the position on the tick its fill week was
    judged. Derived from the tick's {i actual} eject transitions and skip set —
    never inferred from the verdict, because an [Unconfirmed] fill on a position
    already exiting via another channel is not an eject. *)
type fill_volume_outcome =
  | Ejected  (** A [volume_eject] [TriggerExit] was emitted for it. *)
  | Skipped_other_exit
      (** {!Volume_eject_runner.update} never considered it: another exit
          channel had already claimed it this tick. The audit surface evaluated
          it anyway — the fill's volume verdict is a property of the fill. *)
  | Held  (** Considered and not ejected (confirmed, or a fail-soft hold). *)

type fill_volume_event = {
  position_id : string;
      (** The filled position whose fill week was judged — joins to
          {!entry_event.position_id}. *)
  confirmation : Volume.breakout_confirmation option;
      (** The §4.2 verdict for the fill week. [None] is the {b no-verdict} case
          ([Volume.classify_breakout] found neither branch evaluable), which the
          F5 runner deliberately {b holds} on: recording it is what makes the
          held-without-verdict population countable alongside the eject rate,
          rather than silently pooled with the confirmed holds. *)
  outcome : fill_volume_outcome;
      (** What actually happened to the position, so a consumer never has to
          guess the eject population from the verdict. *)
}
(** Event captured when the F5 at-fill volume check judges a freshly-filled
    ticket's fill week.

    Emitted for {b every} evaluable fill-week LONG holding, not only the ejected
    ones and not only the ones {!Volume_eject_runner.update} was allowed to act
    on — the eject transition already surfaces in [trades.csv] via its
    [volume_eject] exit trigger, so on its own it cannot separate "confirmed and
    held" from "no verdict and held", nor from "unconfirmed but already exiting
    elsewhere". {!outcome} carries that last distinction. Only emitted when
    [Weinstein_strategy_config.volume_confirm_at_fill_armed] is [true]; under
    the default config no event is ever produced and the audit row's verdict
    stays absent. *)

type exit_event = {
  position_id : string;
  symbol : string;
  exit_date : Date.t;
  exit_price : float;
  exit_reason : Trading_strategy.Position.exit_reason;
      (** Raw exit reason from the [Position.TriggerExit] kind. The backtest
          layer maps this into a {!Backtest.Stop_log.exit_trigger}. *)
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;
  stage_at_exit : Weinstein_types.stage;
  rs_trend_at_exit : Weinstein_types.rs_trend option;
  distance_from_ma_pct : float;
      (** [(exit_price - ma_value) / ma_value] at exit time. Positive if exit
          was above the MA, negative if below. [0.0] when the MA could not be
          read. *)
  max_favorable_excursion_pct : float;
      (** Largest favourable move during the hold, as a fraction of entry price,
          over the hold's {b weekly} bars. For a long:
          [(max weekly high - entry_price) / entry_price]; for a short, mirrored
          on the low. [0.0] when bars for the hold window are unavailable. *)
  max_adverse_excursion_pct : float;
      (** Largest adverse move during the hold, as a fraction of entry price
          (typically negative), over the hold's {b weekly} bars. For a long:
          [(min weekly low - entry_price) / entry_price]; for a short, mirrored
          on the high. [0.0] when bars are unavailable. *)
}
(** Event captured at exit-decision time. *)

type cascade_drop = {
  analysis : Stock_analysis.t;
      (** The candidate's decision-time analysis — stage, RS, volume. The
          screener's own outcome record carries only what the analysis does not
          (score / grade), so the two together are the full row. *)
  sector : Screener.sector_context;
  side : Trading_base.Types.position_side;
      (** Which cascade evaluated it. The two sides score and gate the same name
          differently, so a candidate can appear once per side. *)
  outcome : Screener.candidate_outcome;
}
(** One candidate the cascade {b evaluated}, with the phase that dropped it — or
    [Admitted] if it survived to the top-N (issue #2490 gap G2).

    Distinct from {!alternative_input}, which covers only candidates that
    reached the {i entry walk} and carries an entry-walk [skip_reason]. This
    covers the full pre-top-N population, whose members were never scored for
    entry at all. Together they span every name the cascade looked at. *)

type cascade_event = {
  date : Date.t;
      (** Friday on which the screen ran — same as [current_date] passed into
          [_screen_universe]. *)
  diagnostics : Screener.cascade_diagnostics;
      (** Per-cascade-phase admission counts. Carried through unchanged from
          [Screener.result.cascade_diagnostics]. *)
  breadth_state : Weinstein_types.breadth_state;
      (** This Friday's [Macro.result.breadth_state] — the five-state read that
          refines [diagnostics.macro_trend]. Recorded alongside the counts so a
          run's artefacts can separate a Deteriorating tape from a Recovering
          one after the fact; the gate itself still keys on [macro_trend]. With
          the breadth-direction read disabled (the default) this is exactly the
          projection of [macro_trend]. *)
  entered : int;
      (** How many of the {!Screener.scored_candidate}s the strategy actually
          entered this Friday — the count of {!Position.transition}s emitted by
          {!Weinstein_strategy.entries_from_candidates}. Sits below
          [diagnostics.long_top_n_admitted + diagnostics.short_top_n_admitted]
          because cash limits, sector concentration, and round-share sizing all
          drop further candidates between the screener output and the actual
          entry list. *)
  candidates : alternative_input list;
      (** Every top-N candidate the entry walk passed over this Friday, with the
          reason — {b unconditionally}, including on Fridays that funded nothing
          (issue #2490 gap G1). Funded candidates are not repeated here: they
          already have their own {!entry_event} / [Trade_audit.entry_decision]
          row, and cross-artefact joins key on [position_id].

          [[]] when [capture_candidates] is [false], which is the default and
          every non-audit context — the projection is not even computed, so the
          default path allocates nothing. *)
  decisions : walk_decision list;
      (** Every top-N candidate the entry walk classified this Friday, in walk
          order, each with one outcome: [Placed] or the skip reason (#3139).
          {b Always} populated, whatever [capture_candidates] says: at most the
          screener's top-N rows per Friday, so the weekly record costs nothing
          worth gating. [[]] on a Friday whose walk had no candidates (a
          macro-blocked tape, an empty top-N); [diagnostics] says which. *)
  drops : cascade_drop list;
      (** Every candidate the {i cascade} evaluated this Friday and where each
          one fell out (G2). Supersedes {!candidates} as the artefact's
          population: it covers the whole post-held/cooldown universe, of which
          the entry walk's top-N is the [Admitted] tail.

          [[]] when [capture_candidates] is [false] — the screener callback is
          not even installed, so the cascade allocates nothing extra. *)
}
(** Event captured at the end of one Friday's cascade. Complements
    [entry_event]: where [entry_event] records a single chosen candidate plus
    its rivals, [cascade_event] records the per-phase activity counts for the
    whole cascade — including phases that filter out every candidate before any
    rival comparison happens. *)

type force_liquidation_event = Portfolio_risk.Force_liquidation.event
(** Event captured every time {!Force_liquidation.check} fires for a position.
    Mirrors [Force_liquidation.event] one-for-one; re-exposed here as part of
    the recorder bundle so the strategy library does not depend on [Backtest.*].
    The backtest-side recorder maps these into a [Force_liquidation_log] for
    [force_liquidations.sexp] persistence and [trades.csv] exit-trigger
    labelling. *)

type reissue_event = {
  reissued_position_id : string;
      (** The fresh id the re-issued [CreateEntering] carries. *)
  original_position_id : string;
      (** The id of the ticket's {b first} placement — the one whose
          {!entry_event} was recorded. Always the root, never an intermediate
          re-issue, however many suspend / re-issue cycles the ticket went
          through. *)
  reissue_date : Date.t;  (** The screen that re-issued the ticket. *)
}
(** A resting long entry ticket withdrawn by the #2976 macro suspension
    ({!Entry_ticket_suspend}) has been re-issued under a new position id (issue
    #2989). No {!entry_event} is recorded for the new id — the entry walk did
    not place it — so this event is the only link from the position that may
    fill back to the placement whose alternatives, installed stop and floor kind
    were recorded. Only emitted when [entry_ticket_macro_suspend] is armed.
    Observability only: the re-issue transition is identical with or without a
    sink. Field labels are distinct from the other events' so no existing
    unannotated [position_id] / [date] access changes resolution. *)

type t = {
  record_entry : entry_event -> unit;
  record_exit : exit_event -> unit;
  record_cascade_summary : cascade_event -> unit;
  record_force_liquidation : force_liquidation_event -> unit;
  record_fill_volume : fill_volume_event -> unit;
      (** Invoked once per position the F5 at-fill check evaluates. Never
          invoked under the default (unarmed) config. *)
  record_stop_move : stop_move_event -> unit;
      (** Invoked once per held position per bar on which the stops pass moved
          its stop without emitting a transition for it (see
          {!stop_move_event}). *)
  record_reissue : reissue_event -> unit;
      (** Invoked once per ticket {!Entry_ticket_suspend} re-issues (see
          {!reissue_event}). Never invoked under the default (unarmed) config.
      *)
  record_stop_decision : Weinstein_stops.Stop_decision.t -> unit;
      (** Invoked by {!Stops_runner.update} for each held position whose stop
          state machine advanced on the tick (issue #2977): every advance, one
          per position per tick (rows are thinned by the sink, not here).
          Observability only — the record is built from the advance the runner
          already made, so any sink leaves every decision unchanged. *)
  capture_candidates : bool;
      (** Whether the strategy should populate {!cascade_event.candidates}.
          [false] in {!noop}, and therefore in live mode and every test that
          does not opt in — the strategy skips the projection entirely, so the
          default path is bit-identical and allocation-free.

          This is a {b recorder} flag, deliberately not a
          [Weinstein_strategy.config] or [Screener.config] field: candidate
          emission is observability, so it must never become a [Variant_matrix]
          axis, never route through [Overlay_validator], and never appear in a
          golden's [config_overrides]. See
          [dev/plans/candidate-emission-2026-08-23.md]. *)
}
(** Recorder bundle. All callbacks are invoked unconditionally by the strategy
    at entry / exit / per-Friday sites; the implementation decides whether to
    persist or drop. *)

val noop : t
(** Recorder that drops every event. Default for callers (tests, live mode) that
    do not wire a backtest collector. *)
