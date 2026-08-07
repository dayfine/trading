(** Weinstein trailing stop state machine.

    Implements the stop management rules from Stan Weinstein's "Secrets for
    Profiting in Bull and Bear Markets" Chapter 6, extended to support both long
    and short positions.

    The stop evolves through three states: [Initial] → [Trailing] → [Tightened].
    It is {b never moved against the position} — never lowered for a long, never
    raised for a short. See individual type docs for state semantics. *)

open Weinstein_types
open Trading_base.Types

include module type of Stop_types
(** @inline *)

module Support_floor = Support_floor
(** Derives the prior correction extreme from a bar history — correction low for
    longs, counter-rally high for shorts. Feeds the [reference_level] argument
    to {!compute_initial_stop}. See the module doc for algorithm details. *)

module Stop_split_adjust = Stop_split_adjust
(** Apply a stock-split factor to a {!stop_state}. Used by the strategy to keep
    absolute stop prices in lockstep with the broker-side share-count rescale on
    a corporate-action split. See the module doc for the contract. *)

module Stop_widen = Stop_widen
(** Floor-widening primitive for {!Initial} stops. Used by the strategy to
    re-wire {!Screener.candidate_params.installed_stop_min_pct} into the
    installed-stop path. See the module doc for the contract. *)

module Vol_scaled_stop = Vol_scaled_stop
(** Volatility-scaled minimum installed-stop distance (default-off). Widens the
    [min_distance_pct] floor fed to {!Stop_widen.widen_initial_to_min_distance}
    in proportion to the candidate's ATR. See the module doc for the contract.
*)

module Catastrophic_stop = Catastrophic_stop
(** Fast-crash absolute stop (default-off, [config.catastrophic_stop_pct]).
    Macro-agnostic trigger armed only in a fast-V decline. See the module doc
    for the contract. *)

module Extension_stop = Extension_stop
(** Extension stop (default-off, [Extension_stop.config]). A wide tail-INSURANCE
    trail for a held long that has run far above its 30-week WMA (blow-off).
    Pure trigger + trail logic; the strategy-side runner
    ({!Extension_stop_runner}) feeds it the holding-window series. See the
    module doc for the contract. *)

(** {1 Core Functions} *)

val compute_initial_stop :
  config:config -> side:position_side -> reference_level:float -> stop_state
(** Compute the initial stop level at the time of entry.

    For a long, [reference_level] is the support floor; the stop is placed just
    below it. For a short, [reference_level] is the resistance ceiling; the stop
    is placed just above it. A round-number nudge is applied in both cases. *)

val compute_initial_stop_with_floor :
  config:config ->
  side:position_side ->
  entry_price:float ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  fallback_buffer:float ->
  stop_state
(** Compute the initial stop using a real support floor derived from bar
    history, falling back to a fixed-buffer proxy when no qualifying correction
    is found.

    When {!Support_floor.find_recent_level} returns [Some floor] (using
    [config.support_floor_lookback_bars] and [config.min_correction_pct]), that
    value is used as the [reference_level]. Otherwise the function falls back to
    [entry_price *. fallback_buffer] for a long, or
    [entry_price /. fallback_buffer] for a short — behaviourally identical to
    the caller's prior direct call to {!compute_initial_stop} with that proxy.

    The returned state is always {!Initial}; the trailing state machine is
    seeded elsewhere (see {!update}).

    Typical use by callers:
    - [entry_price]: the candidate's suggested entry (breakout price).
    - [bars]: the accumulated daily bar history for the symbol.
    - [as_of]: the entry date (usually today's market-close date).
    - [fallback_buffer]: the same buffer the caller used before this primitive
      existed — e.g. 1.02 for a 2% loose stop on the long side.

    Implementation note: this is a thin wrapper over
    {!compute_initial_stop_with_floor_with_callbacks}. It builds a {!callbacks}
    record via {!callbacks_from_bars} (which applies [as_of] filtering and
    [config.support_floor_lookback_bars] truncation up-front) and threads it
    through. Behaviour is bit-identical to the callback API for the same
    underlying bar inputs. *)

(** {1 Callback API} *)

type callbacks = Support_floor.callbacks
(** Bundle of bar-field callbacks for the support-floor lookup, re-exported from
    {!Support_floor.callbacks}. The bundle exposes a {b pre-windowed} view of
    the daily bars: [as_of] filtering and lookback truncation are applied at
    construction time, leaving a contiguous, cap-trimmed window that the
    algorithm scans by day offset alone. Day offset [0] is the most recent bar;
    offset [n_days - 1] is the oldest. See {!Support_floor.callbacks} for
    field-level documentation. *)

val callbacks_from_bars :
  config:config ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  callbacks
(** [callbacks_from_bars ~config ~bars ~as_of] constructs a callback bundle by
    delegating to {!Support_floor.callbacks_from_bars} with
    [lookback_bars = config.support_floor_lookback_bars]. Used internally by
    {!compute_initial_stop_with_floor}; exposed so panel-backed callers and
    tests can build the bundle the same way the wrapper does. *)

val compute_initial_stop_with_floor_with_callbacks :
  config:config ->
  side:position_side ->
  entry_price:float ->
  callbacks:callbacks ->
  fallback_buffer:float ->
  stop_state
(** [compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
     ~callbacks ~fallback_buffer] is the indicator-callback shape of
    {!compute_initial_stop_with_floor}. [bars] and [as_of] are baked into the
    [callbacks] bundle and no longer parameters here.

    Pure function: same callback outputs and inputs always produce the same
    [stop_state]. The wrapper {!compute_initial_stop_with_floor} guarantees
    byte-identical results for any bar-list inputs by constructing callbacks
    that index the same precomputed window the bar-list path used to walk
    inline.

    {b split_safe_floors.} When [config.split_safe_floors] is [true] the bundle
    is rescaled onto its split/dividend-adjusted basis before the scan: each
    offset's high / low is multiplied by that bar's factor
    [get_adjusted_close /. get_close], and the close is replaced by the adjusted
    close (not [raw *. factor] — the published value itself). Replacing the
    close matters under [Close] anchor mode, where the scan reads it: leaving it
    raw would measure adjusted highs / lows against raw closes. Default [false]
    scans the bundle exactly as supplied — an exact no-op. This is the {b same}
    rescale the bar-list path gets (that path builds a bundle and calls straight
    through to here), so a split inside the lookback window is handled
    identically whichever path the caller uses.

    {b The rescale is all-or-nothing.} A bar admits a factor only when both
    [get_close] and [get_adjusted_close] are real positive numbers. If {e any}
    offset in the window fails that test, the whole bundle is scanned unrescaled
    — exactly as the flag-off path would. So this function returns either the
    correct adjusted-basis answer or the flag-off answer, never a third one, and
    the scanned window is always on exactly one price basis. A bundle with no
    adjusted-close data (all [None], all NaN, or simply equal to [get_close]) is
    therefore inert under the flag rather than degraded. *)

val floor_is_structural_with_callbacks :
  config:config -> side:position_side -> callbacks:callbacks -> bool
(** [floor_is_structural_with_callbacks ~config ~side ~callbacks] is [true] iff
    {!compute_initial_stop_with_floor_with_callbacks} (same [config], [side] and
    bundle) installs the {b structural} floor rather than falling back to the
    fixed buffer.

    The callback-shaped sibling of {!floor_is_structural}, and the correct
    source for the [stop_is_structural] display flag on the panel/callback path:
    it runs the same internal scan the stop computation does — honouring both
    [config.support_floor_anchor_mode] and [config.split_safe_floors] — so the
    flag and the installed level can never disagree. Pure function. *)

val floor_is_structural :
  config:config ->
  side:position_side ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  bool
(** [floor_is_structural ~config ~side ~bars ~as_of] is [true] iff the bar-list
    support-floor path finds a qualifying counter-move in the lookback window —
    i.e. iff {!compute_initial_stop_with_floor} (same [config], [side], [bars],
    [as_of]) installs the {b structural} floor rather than falling back to the
    fixed buffer.

    Single source of truth for the [stop_is_structural] display flag: it builds
    the callbacks through the {b same} internal path
    {!compute_initial_stop_with_floor} uses — honouring both
    [config.support_floor_anchor_mode] (Wick vs Close) and
    [config.split_safe_floors] (raw vs adjusted-basis bars) — so the flag and
    the installed level can never disagree. (Before this function existed the
    flag was computed via the Wick-only bar-list
    {!Support_floor.find_recent_level}, which silently diverged from a
    [Close]-anchored or split-safe level.) Pure function. *)

(** Which price basis a support-floor scan actually ran on — the telemetry for
    [config.split_safe_floors]'s whole-window fallback.

    The fallback is by design {b silent} in the answer it produces: when the
    window cannot be rescaled the scan returns exactly the flag-off level, which
    is indistinguishable from a flag-on window that legitimately measured to the
    same number. This type restores the distinction. Collapsing [Flag_off] into
    [Raw_fallback] would reproduce the very ambiguity the type exists to remove,
    and collapsing [Empty_window] into it would count non-events as inertness.

    {b Reading it as a metric.} The inert fraction of a [split_safe_floors true]
    arm is [Raw_fallback / (Raw_fallback + Adjusted)]. [Empty_window] is
    excluded from {e both} terms — a symbol with no bars in the lookback had
    nothing to scan, so it is neither a success nor a degradation of the
    mechanism. [Flag_off] appearing at all in a flag-on arm is a wiring alarm,
    not a data point.

    That denominator can be {b zero} — an arm in which every decision was
    [Empty_window] (or [Flag_off], or which recorded no decisions at all) makes
    the fraction undefined, and a [0/0] rendered as a blank cell is
    indistinguishable from "this column was never wired up". Those two states
    demand opposite responses: disqualify the arm for lack of exposure, versus
    go and fix the harness. Do not compute this ratio ad hoc. Populations of
    these tags are counted in exactly one place —
    [Backtest.Split_safe_metric.inertness_of_tally], over the audit-layer
    re-declaration [Trade_audit.split_safe_basis] — which returns a variant
    whose undefined case is named and carries the tally that says which cause it
    was.

    {b Why it matters.} Whole-window fallback trips on a {e single} unusable
    cell anywhere in [config.support_floor_lookback_bars], so a walk-forward arm
    over [((stops_config ((split_safe_floors true))))] can be substantially
    inert with no signal other than "on == off" in aggregate. An ACCEPT computed
    over a partly-inert surface is uninterpretable
    ([.claude/rules/mechanism-validation-rigor.md]); this tag lets a run report
    {e what fraction} of its decisions were inert before the mechanism is
    promoted. *)
type split_safe_basis =
  | Flag_off
      (** [config.split_safe_floors] is [false]: no basis decision was taken and
          the raw bundle was scanned. Distinct from {!Raw_fallback} — the raw
          scan here is the configured behaviour, not a degradation. *)
  | Adjusted
      (** Flag on and every offset in the window was rescalable: the scan ran on
          the split/dividend-adjusted basis. This is the only state in which the
          mechanism did anything. *)
  | Raw_fallback
      (** Flag on but at least one offset was unusable (missing / NaN /
          non-positive raw or adjusted close), so the whole window degraded to
          raw. The level returned equals the flag-off level; only this tag says
          so. *)
  | Empty_window
      (** Flag on, but the window has no bars ([n_days = 0]) — e.g. a symbol
          with no history in [config.support_floor_lookback_bars]. There was
          nothing to rescale and nothing to scan, so this is a {e non-event},
          not a degradation. Held distinct from {!Raw_fallback} because folding
          it in would inflate the inert-fraction numerator with symbols the
          mechanism was never given a chance to act on. *)
[@@deriving show, eq, sexp]

val split_safe_basis_of_callbacks :
  config:config -> callbacks:callbacks -> split_safe_basis
(** [split_safe_basis_of_callbacks ~config ~callbacks] reports the basis
    {!compute_initial_stop_with_floor_with_callbacks} and
    {!floor_is_structural_with_callbacks} scan this bundle on, for this config.

    Not a re-derivation: the branch that picks the basis and the branch that
    builds the scanned bundle are the {b same} branch internally. This is a
    {b structural} property — there is no second decision site that {e could}
    drift — rather than a behavioural one: any faithful re-derivation would
    agree by construction and so cannot be distinguished by a test. What tests
    can and do pin is that the tag tracks the branch (invert the branch and the
    telemetry suite reddens). The structural form is what made the #2167 drift
    class unrepresentable here, not merely absent.

    Pure function; does not change any stop level.

    {b Coverage caveats for aggregate reporting.} This is the entrypoint the
    strategy's entry path calls, and its result is recorded per {e entered}
    position (via [Audit_recorder.entry_event] into [trade_audit.sexp]). So an
    inert fraction computed from a run is narrowed twice:
    - {b entries, not candidates.} Screened-and-skipped candidates scan a floor
      too but carry no stop fields in the audit.
    - {b entry-time, not stop maintenance.} [Stop_recompute] and [Stop_thread]
      also scan under the flag and are {e not} tagged today.

    Both narrowings understate how much of a run the flag touched. Name the
    denominator when reading the number. *)

val split_safe_basis_of_bars :
  config:config ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  split_safe_basis
(** Bar-list sibling of {!split_safe_basis_of_callbacks}, built through the same
    {!callbacks_from_bars} path {!compute_initial_stop_with_floor} uses. Exposed
    for the bar-list stop-maintenance callers; no caller is wired to it yet, so
    the caveats on {!split_safe_basis_of_callbacks} describe what a run actually
    reports. *)

val check_stop_hit :
  ?on_close:bool ->
  state:stop_state ->
  side:position_side ->
  bar:Types.Daily_price.t ->
  unit ->
  bool
(** [true] if the bar's trigger price crossed the stop level.

    Default ([on_close = false]) uses the intra-bar extreme — Long: triggered by
    [low_price ≤ stop_level]; Short: [high_price ≥ stop_level].

    With [on_close = true] the trigger uses the bar's [close_price] instead
    (Long: [close ≤ stop_level]; Short: [close ≥ stop_level]) — Weinstein's
    weekly-close rule: an intra-bar wick beyond the stop does not trigger unless
    the bar closes beyond it. On the weekly strategy cadence the bar is a weekly
    bar, so this is the weekly close. *)

val get_stop_level : stop_state -> float
(** Extract the current stop price from any state. *)

(** {1 Update} *)

val update :
  config:config ->
  side:position_side ->
  state:stop_state ->
  current_bar:Types.Daily_price.t ->
  ma_value:float ->
  ma_direction:ma_direction ->
  stage:stage ->
  stop_state * stop_event
(** Advance the stop state machine by one price period.

    - [config]: tuning parameters for stop behavior.
    - [side]: direction of the position ([Long] or [Short]).
    - [state]: current stop state.
    - [current_bar]: OHLCV bar for this period.
    - [ma_value]: current 30-week moving average value.
    - [ma_direction]: whether the MA is rising, flat, or falling this period.
    - [stage]: Weinstein stage classification for this period.

    Calling cadence is the caller's responsibility — typically once per weekly
    bar, but the function itself is period-agnostic.

    The stop is never moved against the position (never lowered for long, never
    raised for short). *)
