(** Late-Stage-2 trailing-stop tightening runner — wires the discarded
    {!Weinstein_types.Stage2.late} MA-deceleration warning into held-position
    risk management.

    {1 Motivation}

    The [late] sub-flag of [Stage2 { late }] (MA-slope deceleration, the
    earliest top-warning the classifier produces) is computed every week but
    consumed {e only} to gate new entries — never to manage a position already
    held. The cross-regime diagnosis
    [dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md] shows [late] fired
    weeks-to-months before 6 of 7 major single-name / index tops, while the
    strategy's actual de-risk trigger (the Stage-4 flip) lagged each top by 5-29
    weeks with price already down 5-44%.

    This runner acts on [late] for held long positions: it
    {b tightens the trailing stop} (raises it toward the current price by a
    configurable buffer) so a mature, decelerating name gives back less when it
    rolls over. It never lowers an existing stop.

    {1 Weinstein authority}

    This is the {b exit-aggressiveness} dial (the trader preset — "get out as
    the Stage-3 top starts forming"), a faithful adaptation of
    [docs/design/weinstein-book-reference.md] §Stage 3 detail (Ch. 2): "Traders:
    exit with profits. Investors: sell half, protect remaining half with tight
    sell-stop below support." The MA-deceleration [late] signal is the leading
    edge of that topping process; raising the protective stop as it fires is
    exactly the book's "tight sell-stop below support" applied a beat earlier.
    The stop stays structural (a fixed fraction below the current close, i.e.
    below recent support), never an arbitrary level divorced from price.

    The strategy {b spine} is untouched: stage classification, the Stage-2-only
    buy rule, breakout+volume entry, the macro/sector gate, and relative
    strength are all unaffected. This runner only adjusts the trailing stop of
    an existing held position.

    {1 Cadence & side}

    Weekly cadence (Friday only), mirroring {!Stage3_force_exit_runner}: the
    [late] flag is a weekly-MA property, so off-cadence ticks are a no-op to
    avoid intra-week classification noise. Long positions only — short-side
    topping semantics differ (book §6.3) and are out of scope. *)

open Core
open Trading_strategy

val update :
  buffer_pct:float ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update ~buffer_pct ~is_screening_day ~positions ~get_price ~prior_stages
     ~current_date] returns an [UpdateRiskParams] transition for every held long
    position whose current stage is [Stage2 { late = true }] and whose tightened
    stop would sit strictly above its existing stop.

    The tightened stop level is [close *. (1.0 -. buffer_pct)] where [close] is
    the current bar's close from [get_price]. The runner reads the position's
    current stage from [prior_stages] (written by {!Stops_runner.update} earlier
    in the same tick) and its existing stop from the position's [Holding]
    risk-params.

    {2 Behaviour}

    {ul
     {- Returns [[]] when [is_screening_day = false] (weekly cadence; the [late]
        flag is a weekly property).
     }
     {- Returns [[]] when [positions] is empty. }
     {- For each held long position in the [Holding] state:
        - Skips unless the stage in [prior_stages] is [Stage2 { late = true }].
          A [Stage2 { late = false }] read, any other stage, or a missing stage
          entry produces no transition.
        - Skips when [get_price] has no bar for the symbol.
        - Computes [candidate = close *. (1.0 -. buffer_pct)] and emits
          [UpdateRiskParams] with [stop_loss_price = Some candidate]
          {b only when} [candidate] is strictly greater than the existing stop
          (or the position has no existing stop). This enforces the
          never-lowered invariant: a stop already at or above the candidate is
          left untouched.
     }
     {- Short positions and non-[Holding] states are skipped without emitting. }
    }

    {2 Never-lowered invariant}

    The runner only ever {e raises} a stop. When the candidate sits at or below
    the existing stop the position is skipped — the trailing stop set by
    {!Stops_runner} (or a prior late-tighten) is preserved. A long's trailing
    stop is monotonically non-decreasing, per book §Stop-Loss Rules.

    {2 No-op default}

    This runner is gated entirely by its caller on
    [config.enable_late_stage2_stop_tighten]; it is only invoked when that flag
    is [true]. With the flag default-off the runner never runs, so behaviour is
    bit-identical to baseline regardless of [buffer_pct]. *)
