open Core
open Stop_types
open Trading_base.Types

(* Round-number nudging lives in {!Stop_nudge}. This adapts it to the stops
   config's [round_number_nudge] distance. *)
let _nudge_round_number ~config ~side price =
  Stop_nudge.nudge_round_number ~nudge:config.round_number_nudge ~side price

let compute_initial_stop ~config ~side ~reference_level =
  (* Half the min-correction threshold: places the initial stop modestly inside
     the reference level without using the full correction distance, which would
     be too loose for an entry stop. *)
  let delta = config.min_correction_pct /. 2.0 in
  let raw_stop =
    match side with
    | Long -> reference_level *. (1.0 -. delta)
    | Short -> reference_level *. (1.0 +. delta)
  in
  Initial
    { stop_level = _nudge_round_number ~config ~side raw_stop; reference_level }

(* Fallback reference when the bar history yields no qualifying counter-move.
   Mirrors the pre-primitive caller behaviour: push the reference point into
   the position's favour by the configured buffer. *)
let _fallback_reference ~side ~entry_price ~fallback_buffer =
  match side with
  | Long -> entry_price *. fallback_buffer
  | Short -> entry_price /. fallback_buffer

type callbacks = Support_floor.callbacks

let callbacks_from_bars ~config ~bars ~as_of =
  Support_floor.callbacks_from_bars ~bars ~as_of
    ~lookback_bars:config.support_floor_lookback_bars

(* A price is usable as an operand of the split/dividend factor only if it is a
   real positive number. NaN-safe without a separate [Float.is_nan] test:
   [Float.(nan > 0.0)] is [false] under IEEE, so NaN falls out here too (pinned
   by the NaN-raw-close bar in [corrupt_close_bars]). *)
let _usable_price p = Float.( > ) p 0.0

(* Per-bar split/dividend factor [f = adjusted_close /. close_price] at
   [day_offset], or [None] when either operand is unusable (NaN, zero, negative,
   or the offset is outside the window). The guard is symmetric across both
   operands — an unusable adjusted close is exactly as disqualifying as an
   unusable raw close, because a factor computed from either is meaningless. *)
let _adjusted_factor (cbs : callbacks) ~day_offset =
  match (cbs.get_close ~day_offset, cbs.get_adjusted_close ~day_offset) with
  | Some raw, Some adj when _usable_price raw && _usable_price adj ->
      Some (adj /. raw)
  | _, _ -> None

(* Can EVERY offset in the window be rescaled? The rescale is all-or-nothing by
   design — see [_scan_basis] for why per-bar degradation is not an option. An
   empty window ([n_days = 0]) has nothing to scan, so it reports [false] and
   takes the cheap path. *)
let _window_is_adjustable (cbs : callbacks) =
  let rec loop i =
    i >= cbs.n_days
    || (Option.is_some (_adjusted_factor cbs ~day_offset:i) && loop (i + 1))
  in
  cbs.n_days > 0 && loop 0

(* The close on the adjusted basis is the published adjusted close itself, not
   [raw *. factor] — same value up to rounding, but exactly what the data source
   wrote. This is load-bearing under [Close] anchor mode, where the scan reads
   the close: leaving it raw would measure adjusted highs / lows against raw
   closes. *)
let _adjusted_close_at (cbs : callbacks) ~day_offset =
  match cbs.get_adjusted_close ~day_offset with
  | Some _ as adj -> adj
  | None -> cbs.get_close ~day_offset

(* Rescale every offset. Caller must have checked [_window_is_adjustable], so
   the [~default:1.0] below is unreachable; it only keeps the expression total. *)
let _rescaled (cbs : callbacks) : callbacks =
  let scaled get ~day_offset =
    Option.map (get ~day_offset) ~f:(fun v ->
        v *. Option.value (_adjusted_factor cbs ~day_offset) ~default:1.0)
  in
  {
    cbs with
    get_high = scaled cbs.get_high;
    get_low = scaled cbs.get_low;
    get_close = _adjusted_close_at cbs;
  }

type split_safe_basis = Flag_off | Adjusted | Raw_fallback | Empty_window
[@@deriving show, eq, sexp]

(* Put a callbacks bundle on its split/dividend-adjusted basis: scale the high /
   low by each bar's factor and replace the close with the adjusted close.
   Inlined mirror of [Adjusted_basis.to_adjusted_basis]
   (analysis/weinstein/snapshot_pipeline) — this A2-forbidden layer cannot
   import analysis/, and the factor is derivable from the [get_adjusted_close]
   accessor every bundle carries. Keep in sync with [Adjusted_basis._factor] by
   hand if that formula ever changes.

   Idempotent: after one pass [get_close] already returns the adjusted close, so
   a second pass computes [f = adj /. adj = 1.0] and changes nothing.

   Applying the rescale at the bundle level rather than the bar level is what
   lets the panel/callback path share it — a [daily_view] has no
   [Daily_price.t] to rewrite, only accessors. The bar-list path is unaffected
   in value terms: scaling [high_price] / [low_price] and setting
   [close_price := adjusted_close] on each bar produces exactly these
   accessors.

   {b All-or-nothing.} If any offset in the window cannot be rescaled, the whole
   bundle is returned untouched and the scan runs on the raw basis, exactly as
   it would with the flag off. Degrading only the offending {e bar} to raw was
   measured and rejected: it leaves one raw bar inside an otherwise-adjusted
   window, and on the 4:1 split fixture that lone raw high (412) out-tops every
   adjusted high (110) and becomes the anchor, yielding the phantom 104.0
   reference this flag exists to eliminate. Whole-window fallback keeps the
   invariant that makes the mechanism sound: {b the scanned window is always on
   exactly one price basis}, so the flag can only produce the correct adjusted
   answer or the flag-off answer, never a third one.

   {b Telemetry (F5).} Whole-window fallback is silent at the single-decision
   level — it returns the flag-off answer, which is indistinguishable from a
   flag-on window that legitimately measured to the same number. So this one
   function returns BOTH the bundle the scan reads and the [split_safe_basis]
   describing which branch produced it. Deriving the basis from a second,
   separate evaluation of [_window_is_adjustable] would let the reported basis
   drift from the basis actually scanned — the #2167 class of bug this track has
   already been bitten by twice. One branch, two outputs.

   The [n_days = 0] branch is what keeps the telemetry a usable {e metric}
   rather than just a tag. [_window_is_adjustable] answers [false] for an empty
   window, so without this branch a symbol with no bars in the lookback would
   report [Raw_fallback] — "the fallback fired" for a window that had nothing to
   scan — inflating the inert-fraction numerator with non-events. It is
   behaviour-preserving: the empty branch returns the bundle untouched, exactly
   as the [Raw_fallback] branch did. *)
let _scan_basis ~config ~(callbacks : callbacks) =
  if not config.split_safe_floors then (callbacks, Flag_off)
  else if callbacks.n_days = 0 then (callbacks, Empty_window)
  else if _window_is_adjustable callbacks then (_rescaled callbacks, Adjusted)
  else (callbacks, Raw_fallback)

(* The bundle the support-floor scan actually reads. Single source for every
   floor consumer — [compute_initial_stop_with_floor_with_callbacks] and
   [floor_is_structural_with_callbacks] — so the installed stop level and its
   [stop_is_structural] classification can never disagree. Under
   [config.split_safe_floors] the bundle is first rescaled onto the adjusted
   basis; default-off returns it untouched (bit-identical). *)
let _scan_callbacks ~config ~callbacks = fst (_scan_basis ~config ~callbacks)

let split_safe_basis_of_callbacks ~config ~callbacks =
  snd (_scan_basis ~config ~callbacks)

let _find_level ~config ~side ~callbacks =
  Support_floor.find_recent_level_with_callbacks
    ~anchor_mode:config.support_floor_anchor_mode
    ~callbacks:(_scan_callbacks ~config ~callbacks)
    ~side ~min_pullback_pct:config.min_correction_pct ()

let compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer =
  let reference_level =
    match _find_level ~config ~side ~callbacks with
    | Some level -> level
    | None -> _fallback_reference ~side ~entry_price ~fallback_buffer
  in
  compute_initial_stop ~config ~side ~reference_level

let floor_is_structural_with_callbacks ~config ~side ~callbacks =
  Option.is_some (_find_level ~config ~side ~callbacks)

let compute_initial_stop_with_floor ~config ~side ~entry_price ~bars ~as_of
    ~fallback_buffer =
  let callbacks = callbacks_from_bars ~config ~bars ~as_of in
  compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer

let floor_is_structural ~config ~side ~bars ~as_of =
  let callbacks = callbacks_from_bars ~config ~bars ~as_of in
  floor_is_structural_with_callbacks ~config ~side ~callbacks

let split_safe_basis_of_bars ~config ~bars ~as_of =
  let callbacks = callbacks_from_bars ~config ~bars ~as_of in
  split_safe_basis_of_callbacks ~config ~callbacks
