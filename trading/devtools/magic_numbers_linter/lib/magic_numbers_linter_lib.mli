(** Core detection logic for the magic-number linter: bare numeric literals in
    [lib/*.ml] files must be routed through a config record or a named constant.

    This library is a line-by-line reimplementation of the removed
    [trading/devtools/checks/linter_magic_numbers.sh] shell script -- same skip
    rules in the same order, same PCRE-style numeric-token extraction semantics,
    same exempt-literal set, same file-discovery rules. The rewrite exists
    purely for speed: the shell version forked ~8-10 subprocesses PER SOURCE
    LINE (grep/wc/sed for comment-depth tracking, quote counting, and candidate
    extraction) -- ~460k-575k process spawns across ~57k lines in ~445
    [lib/*.ml] files, ~35 minutes under Docker-on-macOS. This library does the
    identical per-line scan in one process, no forking: ~35min -> low seconds.

    See [magic_numbers_linter.ml] (in the parent directory) for the thin CLI
    entry point, and [test/test_magic_numbers_linter_lib.ml] for the pinned
    regression suite covering every rule enumerated below. Generic char-level
    string helpers live in [String_utils] and file-discovery (which files get
    scanned, which are excluded) lives in [File_discovery] -- both split out of
    this module purely to stay under the file-length linter's limit; the
    detection rules and their order are unchanged.

    {1 The exempt surface, in full}

    The skip/exempt rules below are WIDE and can be surprising in practice --
    e.g. a dispatcher probe was once silently swallowed by the
    named-constant-binding rule below, because a [let x = <call ...>] line looks
    nothing like a magic-number false positive until this list is read. Read it
    before assuming a line obviously should be flagged.

    A LINE is skipped entirely (regardless of what numeric literals it contains)
    by {!should_skip_line} if it matches ANY of the following, in this order:
    - Contains [(*] or [*)] -- inside, or opening/closing, a comment.
    - Contains the substring [e.g.] -- explanatory prose, not code. This rule
      exists because of the #409 incident: a docstring example like "e.g. 42"
      was flagged as a magic number.
    - Ends with a backslash -- an OCaml multi-line string continuation.
    - Has an odd number of double-quote characters -- this line is itself a
      continuation of a string literal opened on a prior line.
    - Matches [= <digit>] or [= -<digit>] anywhere in the line -- a record field
      default or negative default (e.g. [field = 42], [y = -5]).
    - Matches [let <name> = ...] or [let <name>=<digit>] anywhere in the line --
      ANY [let]-binding is treated as a named-constant definition, not just ones
      binding a literal number directly. [let x = f 42 100] is skipped in full,
      not just up to the first numeric literal.
    - Contains [config.] -- ANY line merely mentioning [config.], not just a
      bare field read; an unrelated magic number elsewhere on a line that also
      references [config.foo] is skipped whole.
    - Contains [->] -- ANY line with an arrow, most commonly a variant-match arm
      (e.g. [Stage1 _ -> 1]), but the rule is a plain substring match, so any
      other appearance of [->] on the line skips it too.
    - Contains [~f:], [~len:], or [~pos:] -- labeled-argument call sites using
      exactly those three labels (no other labels are recognized).

    A NUMERIC TOKEN, once extracted by {!extract_candidates}, is additionally
    exempt (never flagged, even on an otherwise-scanned line) by
    {!is_exempt_literal} if it is exactly one of: [0], [1], [0.0], [1.0], [2.0],
    [0.5], [100.0]. NOTE: [0] and [1] can never actually be produced by
    {!extract_candidates} -- its integer branch requires a 2+ digit run, so a
    bare single digit is never a candidate in the first place. Those two
    exempt-literal arms are dead code, kept only because the original shell
    script's exemption comment named them explicitly; do not assume any test
    exercises them. *)

val should_skip_line : string -> bool
(** [should_skip_line line] is [true] if [line] should be skipped in full -- see
    the "exempt surface" section above for the exact rule set and order. A
    skipped line is never scanned for numeric candidates at all, regardless of
    what it contains. *)

val extract_candidates : string -> string list
(** [extract_candidates line] returns every numeric token in [line] that looks
    like a bare literal: a run of 2+ digits, or a float with 1+ digits on each
    side of a decimal point (e.g. [42], [3.14] -- never a bare single digit like
    [7]). A candidate must not be glued to an identifier, another digit, or a
    dot on either side: [identifier42value] and [v1.2.3] (each digit run touches
    an adjacent letter or dot) produce no candidates at all. Candidates are
    returned in left-to-right order. This function does not consult
    {!is_exempt_literal} or quoted-string context -- callers must apply both
    afterward.

    This is a character-level scan, not a real numeric-literal parser: OCaml
    syntax such as scientific notation ([1e5]), hex ([0x2A]), underscore
    separators ([42_000]), or a trailing/leading bare decimal point ([12.],
    [.55]) are NOT recognized as numeric candidates at all -- see the test suite
    for the exact (non-)behavior on each. *)

val is_exempt_literal : string -> bool
(** [is_exempt_literal token] is [true] for the fixed exempt set: [0], [1],
    [0.0], [1.0], [2.0], [0.5], [100.0]. See the "exempt surface" section above
    -- [0] and [1] are unreachable in practice since {!extract_candidates} never
    emits a bare single digit. *)

val strip_quoted_segments : string -> string
(** [strip_quoted_segments line] removes every double-quoted span from [line],
    assuming an even (balanced) quote count -- callers must verify that first.
    Used to decide whether a numeric candidate sits inside a string literal (and
    is therefore not a magic number) versus outside one: a candidate is only a
    real violation if it still appears in the stripped text. *)

val has_let_binding : string -> bool
(** [has_let_binding line] is [true] if [line] contains a [let <name> = ...] or
    [let <name>=<digit>] pattern anywhere. One of the rules folded into
    {!should_skip_line}; exposed separately for targeted testing. *)

val has_eq_digit_default : string -> bool
(** [has_eq_digit_default line] is [true] if [line] contains [= <digit>] or
    [= -<digit>] anywhere (a record field default or negative default). One of
    the rules folded into {!should_skip_line}; exposed separately for targeted
    testing. *)

val scan_file_lines : path:string -> string list -> string list
(** [scan_file_lines ~path lines] scans an already-read file's [lines] (as they
    would be read from [path]) and returns violation strings, in top-to-bottom
    source order, formatted as [<path>: <num> in: <line>]. Tracks [(* ... *)]
    comment-depth across lines -- a numeric literal inside a still-open
    multi-line comment is never a candidate -- and applies {!should_skip_line},
    {!extract_candidates}, {!is_exempt_literal}, and {!strip_quoted_segments} to
    each non-skipped, non-comment line. *)

val scan_file : string -> string list
(** [scan_file path] reads [path] and returns its violations via
    {!scan_file_lines}. If [path] exists but cannot be read (permission, I/O, or
    a directory masquerading as a [*.ml] path), returns a single-entry
    diagnostic violation rather than silently passing (H-CHECK-SETE-DIAGNOSTICS
    FINDING-1). If [path] no longer exists (vanished between discovery and scan
    -- a TOCTOU race), returns []. *)

val lint : trading_root:string -> exceptions_conf:string -> string list
(** [lint ~trading_root ~exceptions_conf] is the full detection pipeline:
    discover files via [File_discovery.collect_lib_ml_files], drop excluded
    paths per [File_discovery.read_magic_number_exclusions] and
    [File_discovery.is_excluded] (see file_discovery.mli), then scan every
    remaining file via {!scan_file}. Returns the flat, ordered violation list;
    the CLI entry point decides how to format/print it and what exit code to
    use. *)
