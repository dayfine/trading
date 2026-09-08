; Warehouse series-tail exceptions (issue #2672).
;
; Symbols listed under keep_tail are NEVER edited by
; Snapshot_pipeline.Series_tail at warehouse build time: their terminal run is
; still classified and still appears in terminal_runs.csv, but with action
; kept_by_exception instead of truncated / stray_dropped.
;
; Use this when the build-time rule would truncate a run a reviewer has decided
; is real — e.g. a genuine terminal collapse that happens to look like an
; administrative stub tail (the rule keys on price shape, so it cannot tell the
; two apart on its own). Read terminal_runs.csv once per vintage and add the
; symbols you disagree with here; the entry is a decision, so say why.
;
; Pass this file to either builder with -tail-exceptions <path>. There is no
; default path: a build's behaviour must never depend on the caller's cwd.
;
; Empty for the 2000 vintage: the 13 truncated symbols are all cash-takeover or
; sub-cent micro-cap stub tails, and the 33 other flagged symbols (prefix
; mis-scales, long low tails) are already kept by the rule's own gates.

; The splice section (issue #2672 class ii) vetoes or replaces
; Snapshot_pipeline.Series_splice's build-time decision on a ticker-reuse
; series. Rules, one per symbol (last wins):
;
;   (keep SYM)              store the series whole, however it classifies
;   (drop SYM)              exclude the symbol from the warehouse entirely
;   (cut_at SYM 2004-12-20) cut here instead of at the rule's last splice,
;                           keeping bars on or after the date
;
; Read splice_actions.csv once per vintage and record the decisions you
; disagree with here; the entry is a decision, so say why. Both sections are
; optional and each module ignores the other's, so this one file (passed as
; -tail-exceptions PATH) carries both.
;
; Empty for the 2000 vintage: the 66 interleaved symbols (SWD 1,215 findings,
; AEZ 694, ICT 589, CLE 412, MEL 98, MVL 80) are genuinely two issuers apiece
; and the 1-2-finding tail (CHS 2004-12-20, AGR 2006-07-05) cuts cleanly.

((keep_tail ())
 (splice ()))
