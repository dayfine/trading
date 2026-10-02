(** Atomic claim of a per-run output directory for [scenario_runner]. *)

val claim_output_root : base:string -> string
(** [claim_output_root ~base] atomically creates the directory [base] and
    returns it. [base] is typically a one-second-granularity timestamped path,
    so two runners started in the same second can collide: the loser sees
    [EEXIST] on the atomic [mkdir] and instead creates (and returns) the
    pid-suffixed sibling [base ^ "-" ^ pid]. An existing [base] and its contents
    are never touched. The parent of [base] must already exist; any error other
    than [EEXIST] on [base] (e.g. [ENOTDIR], [EACCES]) propagates as
    [Core_unix.Unix_error]. *)
