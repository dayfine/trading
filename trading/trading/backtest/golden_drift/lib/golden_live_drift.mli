(** Golden-vs-live config drift check (issue #2403).

    A golden scenario's effective Weinstein config is
    [default_config + the spec's config_overrides]. The {e live} config — what
    the weekly picks actually run — is
    [default_config + dev/weekly-picks/live-config-overrides.sexp]. Nothing used
    to relate the two: a golden inherited whatever the spec it was copied from
    happened to arm, and drifted from live silently, so every topline quoted off
    that golden described a configuration nobody runs.

    This module makes the drift {b declared}. A golden may deviate — scenarios
    that isolate a mechanism {e should} — but each deviating field must be named
    in the spec's [deviates_from_live] block together with a one-line reason
    (which is enforced, not merely conventional — see {!declared_deviations}):

    {v
    (deviates_from_live
     ((enable_short_side "long-only cell; the code default (and live) is on")
      (enable_stage3_force_exit "record-convention arming; live leaves it off")))
    v}

    [deviates_from_live] is data-only: {!Scenario.t} carries
    [@@sexp.allow_extra_fields], so the runner parses and ignores it and no
    backtest number moves. It is read here straight from the spec's raw sexp.

    Two failure shapes are reported, so declarations stay honest in both
    directions:
    - an {b undeclared deviation} — the field differs but the spec is silent;
    - a {b stale declaration} — the spec names a field that no longer differs
      (someone unified the value and left the note behind).

    Scenarios whose [strategy] is not {!Backtest.Strategy_choice.Weinstein} (BAH
    benchmarks, SPY-only sleeves, …) have no full Weinstein config to compare
    and are skipped; a [deviates_from_live] block on such a spec is accepted and
    ignored. *)

type deviation = {
  field : string;  (** Top-level {!Weinstein_strategy.config} field name. *)
  golden : string;
      (** The golden's value, rendered as a sexp. For a nested config record
          only the differing leaves are rendered, so the message points at the
          knob rather than at the whole sub-record. Long renderings are
          truncated. *)
  live : string;  (** The live value, rendered the same way. *)
}

type finding =
  | Undeclared_deviation of deviation
      (** The field differs from live and the spec's [deviates_from_live] does
          not name it. *)
  | Stale_declaration of string
      (** [deviates_from_live] names this field but it no longer differs from
          live — the note outlived the drift and must be removed. *)

type spec_report = {
  spec_path : string;
  skipped_reason : string option;
      (** [Some why] when the spec was not compared at all (non-Weinstein
          strategy). [findings] is then always empty. *)
  findings : finding list;
}

val live_config : overrides_path:string -> Weinstein_strategy.config
(** [live_config ~overrides_path] is the default config with every overlay in
    [overrides_path] (normally [dev/weekly-picks/live-config-overrides.sexp])
    deep-merged in, via the same {!Backtest.Overlay_validator.apply_overrides}
    path the scenario runner and the weekly-picks generator use. Raises
    [Failure] on an unreadable file, a malformed overlay, or a key that does not
    resolve to a real config field. *)

val diff_configs :
  golden:Weinstein_strategy.config ->
  live:Weinstein_strategy.config ->
  deviation list
(** [diff_configs ~golden ~live] is one entry per top-level config field whose
    sexp rendering differs between the two, in record-declaration order. Both
    configs are expected to derive from the same default base, so fields neither
    side arms compare equal and never appear. *)

val declared_deviations : string -> string list
(** [declared_deviations spec_path] is the field names listed in the spec's
    [deviates_from_live] block, or [[]] when the block is absent. Raises
    [Failure] if the block is present but malformed — it must be a list of
    [(<field> "<reason>")] pairs, and the reason is required: a bare [(field)]
    or an empty reason would silence the check while recording nothing, so both
    are rejected. *)

val check_spec : live:Weinstein_strategy.config -> string -> spec_report
(** [check_spec ~live spec_path] loads the scenario, resolves its
    [config_overrides] against the default base, and reports every undeclared
    deviation from [live] plus every stale declaration. Raises [Failure] if the
    spec does not parse or an overlay key does not resolve. *)

val check_dirs :
  live:Weinstein_strategy.config -> string list -> spec_report list
(** [check_dirs ~live dirs] runs {!check_spec} over every [*.sexp] directly
    inside each directory, sorted by path. Raises [Failure] if a directory does
    not exist — a silently-empty sweep is the failure mode this check exists to
    prevent. *)

val render_report : spec_report list -> string
(** Human-readable multi-line summary: one line per finding, prefixed by the
    spec path, plus a trailing counts line. Empty findings render as a single OK
    line. *)

val failure_count : spec_report list -> int
(** Total findings across all reports. Zero means every golden's drift is fully
    and accurately declared. *)
