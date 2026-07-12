(** Pure detection of {b rename-twins} in a set of price series.

    A rename-twin is the same company listed under two (or more) tickers with a
    near-identical price series — old + new ticker after a symbol rename, or a
    vendor duplicating one underlying series onto several symbols. Historical
    point-in-time universe snapshots contain these (e.g. NLS/BFX, ISIS/IONS, the
    JW-A/JWA/WLY triple), and a backtest that holds both legs double-counts the
    same position.

    This module is the {e builder-side} detector: it compares full
    adjusted-close series, which is a stronger, lower-false-positive criterion
    than the trade-level heuristic in the post-run validator (same entry/exit
    date + price within a tolerance). The two cross-check rather than duplicate;
    series that merely coincide in price for a short window (e.g. two unrelated
    large-caps that happen to trade near the same price on one day) are {b not}
    twins under this criterion.

    The detector is a pure function of [Config.t] + a list of {!series} (no
    filesystem, no bar loading), so it is directly unit-testable.
    {!Build_scenario_snapshots} owns the loading + wiring. *)

open Core

module Config : sig
  type t = {
    enabled : bool;
        (** Master switch. Defaults to [false] so the detector is a no-op (empty
            report, no symbol dropped) unless a build explicitly arms it —
            existing warehouses and goldens stay reproducible. *)
    min_overlap_days : int;
        (** Two symbols are only twin-eligible if their series share at least
            this many dates. Guards against short coincidental overlaps being
            called twins. *)
    match_fraction : float;
        (** A twin requires strictly more than this fraction of the overlapping
            dates to have near-identical adjusted closes. *)
    close_epsilon : float;
        (** Relative tolerance for "near-identical" on a single date: two closes
            [a] and [b] match when [|a - b| / max |a| |b| <= close_epsilon]. *)
    prefilter_rel_tol : float;
        (** Internal perf knob. The prefilter only emits a candidate pair when
            two symbols sit within this relative gap on a shared anchor date.
            Must be [>= close_epsilon] (looser) so genuine twins are never
            filtered out before the full compare; kept small so near-equal price
            runs stay short. *)
  }
  [@@deriving sexp, equal]

  val default : t
  (** Default config: disabled; [min_overlap_days = 100],
      [match_fraction = 0.95], [close_epsilon = 1e-4],
      [prefilter_rel_tol = 2e-2] — the criterion the visual audit used. *)
end

type series = {
  symbol : string;
  data_end : Date.t;
      (** Last date on which the symbol has a bar — the rename-survivor
          tiebreak. The later-ending leg is the survivor. *)
  closes : (Date.t * float) array;
      (** Adjusted closes, {b sorted ascending by date}, one entry per trading
          day the symbol has. *)
}
[@@deriving sexp_of]

type pair_match = {
  survivor : string;
  dropped : string;
  overlap_days : int;  (** Number of dates the two series share. *)
  match_fraction : float;
      (** Fraction of overlapping dates whose closes matched within
          [close_epsilon]. *)
}
[@@deriving sexp_of, equal]

type group = {
  survivor : string;  (** The kept leg (latest [data_end]; ties → min). *)
  dropped : string list;  (** The excluded legs, sorted ascending. *)
  matches : pair_match list;
      (** One entry per dropped leg, measuring it against [survivor]. *)
}
[@@deriving sexp_of, equal]

type report = {
  config : Config.t;
  groups : group list;  (** Detected twin groups, sorted by [survivor]. *)
  dropped_symbols : string list;
      (** Flattened, sorted union of every group's dropped legs — the set
          {!survivors} removes from a symbol list. *)
}
[@@deriving sexp_of]

val detect : Config.t -> series list -> report
(** [detect config series] finds rename-twin groups. When [config.enabled] is
    [false] it returns an empty report (no group, no dropped symbol). Otherwise
    it prefilters candidate pairs by shared anchor-date price proximity,
    verifies each with the full overlap/match-fraction criterion, unions
    verified twin edges into connected components (so triples are one group),
    and picks the latest-[data_end] leg of each component as the survivor.

    {b Limitation (v1).} A dropped leg is excluded entirely; any
    genuinely-independent tail it may have outside the survivor's window is
    lost. This is appropriate for true rename-twins (duplicated series) but is a
    coarse choice for partial overlaps. The prefilter also assumes reasonably
    dense (daily) overlap; extremely sparse overlaps may be missed. *)

val survivors : report -> all_symbols:string list -> string list
(** [survivors report ~all_symbols] returns [all_symbols] with every entry in
    [report.dropped_symbols] removed, preserving the input order. With a
    disabled-config (empty) report this is [all_symbols] unchanged — the
    bit-identical passthrough. *)

val render : report -> string
(** [render report] formats the config and each detected group (survivor,
    dropped legs with their overlap days + match fraction) as human-readable
    multi-line text for the sidecar report file + stderr summary. *)
