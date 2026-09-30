(** Stage classification and the MA the trailing-stop machine reads, for one
    held symbol on one tick.

    Extracted from {!Stops_runner} (which sits at the file-length soft limit) so
    the optional trailing-stop MA ([trailing_stop_ma_period], issue #3038) can
    be added without growing the runner. *)

val default_stage_and_ma_for_side :
  Trading_base.Types.position_side ->
  Weinstein_types.stage * Weinstein_types.ma_direction
(** Position-favourable stage + MA direction default for warmup periods (fewer
    than [stage_config.ma_period] weekly bars). The return drives
    {!Weinstein_stops.update} into its no-tighten branch: Stage 2 + Rising for a
    long, Stage 4 + Declining for a short. Hardcoding [Stage2 + Flat] for shorts
    tightened on every warmup tick (the G1 pathology, see
    [dev/notes/short-side-gaps-2026-04-29.md]). *)

val trailing_ma_value :
  ?ma_cache:Weekly_ma_cache.t ->
  stage_config:Stage.config ->
  period:int ->
  symbol:string ->
  Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  float option
(** [trailing_ma_value ?ma_cache ~stage_config ~period ~symbol weekly] is the
    current (week offset 0) weekly MA of [weekly] over [period] weeks, computed
    with [stage_config]'s MA type ([{ stage_config with ma_period = period }]).
    [None] when [weekly.n < period].

    @raise Invalid_argument if [period <= 0]. *)

val compute :
  ?ma_cache:Weekly_ma_cache.t ->
  ?prior_stage_ma_values:float Core.Hashtbl.M(Core.String).t ->
  ?trailing_stop_ma_period:int ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  bar_reader:Bar_reader.t ->
  as_of:Core.Date.t ->
  prior_stages:Weinstein_types.stage Core.Hashtbl.M(Core.String).t ->
  symbol:string ->
  side:Trading_base.Types.position_side ->
  fallback_price:float ->
  to_stop_basis:(float -> float) ->
  unit ->
  Weinstein_types.ma_direction * float * Weinstein_types.stage
(** [compute ...] returns [(ma_direction, stop_ma, stage)] for [symbol].

    Reads and updates [prior_stages] so Stage1->Stage2 transition detection
    works across calls. With fewer than [stage_config.ma_period] weekly bars it
    returns [(direction, fallback_price, stage)] from
    {!default_stage_and_ma_for_side} and touches nothing.

    Otherwise the stage, MA direction, the [prior_stages] update and the
    [prior_stage_ma_values] mirror all come from the stage MA
    ([stage_config.ma_period]). The returned [stop_ma] is:
    - the stage MA when [trailing_stop_ma_period] is [None] (the default —
      bit-identical to the pre-#3038 runner);
    - the [Some n]-week MA ({!trailing_ma_value}) otherwise, falling back to the
      stage MA when the view holds fewer than [n] weeks.

    [to_stop_basis] ({!Stop_ma_basis.for_stops}) is applied to [stop_ma] only —
    never to the raw warmup [fallback_price] nor to the mirrored value.

    [ma_cache] threads through to the panel callbacks (cache keyed by MA type +
    period, so a trailing period reads its own entry). *)
