(** Append-only ledger of every backtest experiment + verdict.

    The ledger gives the discrete feature/mechanism search a memory: every
    hypothesis we test (and especially every rejection) is recorded as a sexp
    entry under [dev/experiments/_ledger/], keyed by a config-hash of the
    effective override blob. Before scaling a matrix run, the search can
    [lookup] a candidate's (config_hash, base_scenario, window_id) against the
    index and skip re-testing a config already rejected on the same window.

    Distinct from the promoted-configs repo (blessed winners + provenance): this
    is the institutional memory of *every attempt + verdict*, including what
    does NOT work. It lives in-repo because history is cheap and co-located with
    the code it describes. Gap D of the systematic experiment-platform program
    ([dev/plans/experiment-platform-2026-05-29.md]). *)

(** Outcome of an experiment after walk-forward CV + (eventually) best-of-N
    correction. [Inconclusive] = ran but the gate neither accepted nor clearly
    rejected (e.g. fold-count guard mismatch, or a near-tie). *)
type verdict = Accept | Reject | Inconclusive [@@deriving sexp, eq]

type fold_aggregate = {
  mean_sharpe : float;
  mean_calmar : float;
  mean_return_pct : float;
  mean_max_drawdown_pct : float;
}
[@@deriving sexp]
(** Means across folds for the four axes the walk-forward report already emits.
    Recorded per variant so a later reader sees the magnitude of the win/loss,
    not just the verdict. *)

type variant_record = {
  label : string;
  config_hash : string;
  aggregate : fold_aggregate option;
}
[@@deriving sexp]
(** One variant within an experiment. [config_hash] is the dedup key (see
    {!config_hash}). [aggregate] is [None] for seed entries recorded without
    machine fold-aggregates (the verdict + hash still make the entry useful for
    dedup). *)

type entry = {
  date : string;
  slug : string;
  hypothesis : string;
  base_scenario : string;
  window_id : string;
  baseline_label : string;
  variants : variant_record list;
  verdict : verdict;
  notes : string;
}
[@@deriving sexp]
(** One experiment. [window_id] is a short human string identifying the OOS
    window geometry (e.g. ["rolling-2010-2026-365-182-31fold"]); the full
    [Window_spec] is intentionally not embedded — the id is a stable label for
    dedup, not a re-runnable artefact. *)

type index_row = {
  config_hash : string;
  base_scenario : string;
  window_id : string;
  verdict : verdict;
  entry_slug : string;
}
[@@deriving sexp]
(** One flat catalog row per (variant, entry): the searchable projection of an
    entry's per-variant verdict over (config, base, window). *)

val config_hash : Sexplib.Sexp.t list -> string
(** [config_hash overrides] is the dedup key for an override blob. Computed from
    the EFFECTIVE config, not the raw override text, so two logically-equal but
    differently-written override blobs hash identically: the overrides are
    applied onto the canonical default [Weinstein_strategy.config] via
    [Backtest.Overlay_validator.apply_overrides], the resulting config is
    [sexp_of]'d to its canonical machine form ([Sexp.to_string_mach]), and that
    string is MD5-digested. Raises [Failure] (via [apply_overrides]) on any
    override key that does not resolve to a real config field. *)

val save_entry : dir:string -> entry -> unit
(** [save_entry ~dir entry] writes [entry] to [<dir>/<date>-<slug>.sexp].
    Append-only: raises [Failure] if the target file already exists, so a re-run
    never silently overwrites recorded history. *)

val load_entry : string -> entry
(** [load_entry path] reads one entry sexp file. *)

val load_index : dir:string -> entry list
(** [load_index ~dir] reads every [*.sexp] entry file in [dir], skipping
    [index.sexp] itself (which is the catalog, not an entry). *)

val build_index : entry list -> index_row list
(** [build_index entries] flattens entries to one [index_row] per (variant,
    entry). *)

val save_index : dir:string -> entry list -> unit
(** [save_index ~dir entries] writes [build_index entries] to
    [<dir>/index.sexp], overwriting (the index is a derived catalog, regenerated
    from the entries, not append-only history). *)

val lookup :
  index_row list ->
  config_hash:string ->
  base_scenario:string ->
  window_id:string ->
  verdict option
(** [lookup rows ~config_hash ~base_scenario ~window_id] returns the recorded
    verdict if this exact (config, base, window) triple was already catalogued,
    else [None]. The dedup query: a [Some Reject] means skip re-running. *)
