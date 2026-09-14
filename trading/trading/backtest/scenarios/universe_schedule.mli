(** Dated point-in-time universe membership — a step function from screening
    date to the set of symbols eligible for entry on that date.

    A schedule is a list of [(date, universe_path)] entries, each path resolved
    against the fixtures root and loaded by {!Universe_file} (so every shape
    that module accepts — [Pinned], [Full_sector_map], and a
    [Composition_from_individuals] {!Universe.Snapshot.t} sexp — works here
    unchanged).

    {b Window semantics.} Entries are sorted by date on load. The entry dated
    [d_i] governs every screening date [d] with [d_i <= d < d_(i+1)]; the FIRST
    entry additionally governs every date before it, and the LAST entry governs
    every date after it. Entries need not be given sorted; duplicate dates are a
    load error.

    {b Candidate membership only.} The schedule gates the screener cascade's
    candidate set (via {!Screener.screen_with_cooldown}'s [?membership_at]) and
    nothing else. The macro gate and sector relative-strength read indices and
    sector ETFs through a separate path and are untouched. A held position in a
    symbol that drops out of a later list is held to its normal exit — no exit,
    stop, or liquidation surface consults the schedule.

    {b Staging.} A scheduled run must stage the UNION of every list's symbols,
    so a name that has dropped out of the current list still prices while held.
    {!union_sector_map} produces that union.

    See [dev/plans/pit-universe-migration-2026-09-14.md] §Step 3a. *)

open Core

type t
(** A loaded schedule: the per-date member sets plus the union sector map.
    Immutable and pure to query. *)

val load : fixtures_root:string -> (Date.t * string) list -> t Status.status_or
(** [load ~fixtures_root entries] resolves each [(date, path)] against
    [fixtures_root], loads it via {!Universe_file.load}, and builds the step
    function.

    Returns [Error Invalid_argument] when [entries] is empty or when two entries
    carry the same date, and [Error Failed_precondition] when a referenced
    universe file resolves to [Full_sector_map] (the [data/sectors.csv] sentinel
    carries no explicit membership list, so it cannot participate in a dated
    schedule). Propagates [Failure] from {!Universe_file.load} for a missing or
    malformed file. *)

val members_at : t -> Date.t -> String.Set.t
(** [members_at t d] is the member set governing screening date [d], per the
    window semantics in the module doc. Total: never raises, and never returns
    the empty set for a successfully loaded schedule. *)

val is_member : t -> string -> Date.t -> bool
(** [is_member t symbol d] is [Set.mem (members_at t d) symbol] — the closure
    shape {!Screener.screen_with_cooldown}'s [?membership_at] argument takes. *)

val union_sector_map : t -> (string, string) Hashtbl.t
(** Symbol → sector over the union of every list in the schedule. On a symbol
    present in several lists with differing sectors, the FIRST occurrence in
    schedule order wins. This is the [sector_map_override] a scheduled run must
    pass to {!Backtest.Runner.run_backtest} so every name that is ever a member
    has bars staged for the whole run. *)

val reject_if_present :
  runner_name:string -> (Date.t * string) list -> unit Status.status_or
(** [reject_if_present ~runner_name schedule] is [Ok ()] for the empty schedule
    and [Error Unimplemented] otherwise, with a message naming
    [universe_schedule] and [runner_name].

    Every scenario consumer that resolves [universe_path] itself — walk-forward,
    rolling-start, barbell, the tuners, the all-eligible diagnostic — must call
    this so a scheduled spec fails loudly on a runner that does not implement
    dated membership, rather than silently running the whole window against the
    single [universe_path]. *)

val sector_map_of_unscheduled :
  fixtures_root:string ->
  runner_name:string ->
  Scenario.t ->
  (string, string) Hashtbl.t option
(** Resolve a scenario's universe for a runner that does NOT implement dated
    membership: rejects a non-empty [universe_schedule] via {!raise_if_present},
    then returns
    [Universe_file.to_sector_map_override (Universe_file.load <universe_path>)]
    — the [sector_map_override] {!Backtest.Runner.run_backtest} takes, with
    [None] meaning "fall back to [data/sectors.csv]".

    This is the one-call form every non-{!Scenario_runner} consumer should use,
    so the rejection cannot be forgotten alongside the resolution it guards. *)

val raise_if_present : runner_name:string -> (Date.t * string) list -> unit
(** Raising form of {!reject_if_present}, for the call sites that resolve a
    universe inside a non-[Result] pipeline. [()] for the empty schedule; raises
    [Failure] carrying the same message otherwise (matching
    {!Universe_file.load}'s failure convention). *)
