(** Initial-stop computation from a support floor / resistance ceiling.

    Extracted from {!Weinstein_stops} (which re-exports every function here
    unchanged) to keep that coordinator under the file-length cap. The public
    contract — argument roles, the [None] fallback, the [split_safe_floors] and
    [support_floor_anchor_mode] semantics — is documented on the corresponding
    {!Weinstein_stops} vals; this interface carries the signatures plus brief
    notes. All functions are pure. *)

open Stop_types
open Trading_base.Types

val compute_initial_stop :
  config:config -> side:position_side -> reference_level:float -> stop_state
(** Initial stop just inside [reference_level] (below it for a long, above for a
    short), with a round-number nudge. See
    {!Weinstein_stops.compute_initial_stop}. *)

type callbacks = Support_floor.callbacks
(** Pre-windowed support-floor callbacks; alias of {!Support_floor.callbacks}.
*)

val callbacks_from_bars :
  config:config ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  callbacks
(** Build the callback bundle from a bar list using
    [config.support_floor_lookback_bars]. See
    {!Weinstein_stops.callbacks_from_bars}. *)

val compute_initial_stop_with_floor_with_callbacks :
  config:config ->
  side:position_side ->
  entry_price:float ->
  callbacks:callbacks ->
  fallback_buffer:float ->
  stop_state
(** Callback-shaped support-floor-aware initial stop. When
    [config.split_safe_floors] the bundle is rescaled onto its
    split/dividend-adjusted basis before the correction low / rally high is
    measured (default-off scans the bundle unchanged, bit-identical). See
    {!Weinstein_stops.compute_initial_stop_with_floor_with_callbacks}. *)

val floor_is_structural_with_callbacks :
  config:config -> side:position_side -> callbacks:callbacks -> bool
(** [true] iff {!compute_initial_stop_with_floor_with_callbacks} (same config,
    side and bundle) installs a structural floor rather than the fixed-buffer
    fallback — it runs the same internal scan, so the two never disagree. See
    {!Weinstein_stops.floor_is_structural_with_callbacks}. *)

(** Which price basis the support-floor scan actually ran on. See
    {!Weinstein_stops.split_safe_basis}. *)
type split_safe_basis =
  | Flag_off  (** [config.split_safe_floors] off — no basis decision taken. *)
  | Adjusted
      (** Flag on and every offset rescalable — scan ran adjusted-basis. *)
  | Raw_fallback
      (** Flag on but some offset unusable — whole-window fallback fired. *)
  | Empty_window  (** Flag on but the window has no bars — nothing to scan. *)
[@@deriving show, eq, sexp]

val split_safe_basis_of_callbacks :
  config:config -> callbacks:callbacks -> split_safe_basis
(** Basis the scan {e would} run on for this bundle. Shares its single branch
    with the scan itself. See {!Weinstein_stops.split_safe_basis_of_callbacks}.
*)

val split_safe_basis_of_bars :
  config:config ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  split_safe_basis
(** Bar-list sibling of {!split_safe_basis_of_callbacks}. See
    {!Weinstein_stops.split_safe_basis_of_bars}. *)

val compute_initial_stop_with_floor :
  config:config ->
  side:position_side ->
  entry_price:float ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  fallback_buffer:float ->
  stop_state
(** Bar-list support-floor-aware initial stop. Builds the bundle via
    {!callbacks_from_bars} and delegates to
    {!compute_initial_stop_with_floor_with_callbacks}, so [split_safe_floors]
    behaves identically on both paths. See
    {!Weinstein_stops.compute_initial_stop_with_floor}. *)

val floor_is_structural :
  config:config ->
  side:position_side ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  bool
(** [true] iff {!compute_initial_stop_with_floor} (same args) installs a
    structural floor rather than the fixed-buffer fallback — built through the
    same internal callbacks path so the two never disagree. See
    {!Weinstein_stops.floor_is_structural}. *)
