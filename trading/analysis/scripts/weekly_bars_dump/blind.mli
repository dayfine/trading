(** Pure blinding primitives for the blind-judge harness: a stable per-symbol
    pseudonym and sequential week labels standing in for real dates. Blinding
    intentionally leaves price levels untouched -- see
    [.claude/skills/blind-judge/SKILL.md]. *)

val pseudonym_of_symbol : string -> string
(** [pseudonym_of_symbol symbol] is a stable pseudonym of the form ["SYM-XXXX"],
    where [XXXX] is 4 uppercase hex digits derived from an MD5 digest of
    [symbol]. Deterministic: the same [symbol] always produces the same
    pseudonym, so repeated queries about one symbol read self-consistently to
    the judge without the judge ever seeing the symbol itself.

    {b Not} cryptographically hiding -- a determined reader could brute-force a
    small ticker universe by hashing candidates. The actual secrecy boundary is
    operational, not cryptographic: the pseudonym is reversible only by
    consulting the operator's separate mapping record (built by the CLI's
    [--mapping-out], never emitted into the judge's input or output channel). *)

val week_labels : int -> string list
(** [week_labels n] is [n] chronological labels [["w1"; "w2"; ...; "wn"]]
    standing in for real dates, the decision week last (label ["wn"]). [[]] for
    [n <= 0]. *)
