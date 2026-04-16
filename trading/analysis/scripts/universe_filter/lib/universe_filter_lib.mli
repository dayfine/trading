(** Universe composition cleanup filter.

    Drops noise symbols (SPACs, warrants, preferreds, unit trusts, indexes,
    etc.) from a flat [(symbol, sector)] row list without touching legitimate
    common stocks or allow-listed ETFs.

    The filter is config-driven so the rule-set can evolve without code changes.
    Configs live under [dev/config/universe_filter/<name>.sexp] and parse into
    {!config} values via {!load_config}. *)

type row = { symbol : string; sector : string } [@@deriving sexp, equal]
(** One row of [data/sectors.csv]. *)

(** A drop rule. Variants are open for extension, but today we only need two:
    regex-based symbol filters and a simple allow-list override. *)
type rule =
  | Symbol_pattern of {
      name : string;  (** Short label used in stats output. *)
      pattern : string;
          (** POSIX / Perl-style regex matched against the symbol. A row is
              dropped when this regex matches [row.symbol]. *)
    }
  | Keep_allowlist of {
      name : string;
      symbols : string list;
          (** Symbols in this list are preserved even if another rule would drop
              them. *)
    }
[@@deriving sexp]

type config = { rules : rule list } [@@deriving sexp]
(** A rule-set. Rules are evaluated per-row in order: the first matching
    [Symbol_pattern] drops the row, unless any [Keep_allowlist] contains the
    symbol, in which case the row is preserved regardless.

    Empty [rules] means no-op — everything is kept. *)

type rule_stat = {
  rule_name : string;
  drop_count : int;
      (** How many rows would have been dropped by this rule, before allow-list
          override. Rows rescued by an allow-list are counted here (so per-rule
          stats show the raw hit count) and the rescue itself is counted
          separately in {!filter_result.rescued_by_allowlist}. *)
}
[@@deriving sexp]

type filter_result = {
  kept : row list;
  dropped : row list;
  rule_stats : rule_stat list;
      (** Per-rule drop counts (raw, pre-rescue). See {!rule_stat.drop_count}.
      *)
  rescued_by_allowlist : int;
      (** Count of rows that at least one [Symbol_pattern] would have dropped
          but were preserved because an allow-list matched. *)
}
[@@deriving sexp]

val filter : config -> row list -> filter_result
(** [filter config rows] applies [config.rules] to [rows] and partitions them
    into kept / dropped with per-rule stats.

    Pure: same input, same output. Does no I/O. *)

val load_config : string -> (config, string) Result.t
(** [load_config path] loads and parses a sexp config file.

    Returns [Error msg] with a descriptive message on:
    - file not found / not readable
    - malformed sexp
    - sexp shape does not match [config_of_sexp]

    Does not silently return an empty / default config on parse failure —
    callers should surface the error. *)

val read_csv : string -> (row list, string) Result.t
(** [read_csv path] reads a [symbol,sector] CSV (with header row). Skips blank
    lines. Returns [Error msg] if the file cannot be opened. *)

val write_csv : string -> row list -> (unit, string) Result.t
(** [write_csv path rows] writes [rows] to [path] with header [symbol,sector].
    Writes atomically via [path.tmp] + rename. *)

val sector_breakdown : row list -> (string * int) list
(** Count rows per sector, sorted by descending count. Convenience for
    before/after summaries. *)
