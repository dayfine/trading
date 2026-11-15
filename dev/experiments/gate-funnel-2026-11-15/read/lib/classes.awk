# classes.awk -- the populations the outcome reads compare (README §Descriptive reads 2-3 and the rule's ride clause),
# one row per (class, date, symbol) that survives the 26-week dedup. POSIX awk; load with -f ../../../price-band-binding-2026-11-13/
# read/lib/dates.awk -f classes.awk.
#
# usage: awk -F'\t' -v NALL=nall.tsv -f dates.awk -f classes.awk open.tsv crowd.tsv macro_events.tsv rows.tsv > classes.tsv
#   open.tsv          date open live_blocked                 (check.awk)
#   crowd.tsv         date symbol rank in_C*_gross in_C*_net (gbc.awk CROWD)
#   macro_events.tsv  date symbol                            (screen events in weeks that were not open, mapped to the
#                                                             screened Friday of their week; the macro proxy)
#   rows.tsv          every Long row                         (cands.awk), date order
# stdout: class  date  symbol, the kept rows only: the first row of a (class, symbol) and every row 182 days or more after
# the last kept one (one row per symbol per 26 weeks, the population screen's convention). The row-weighted tier
# classes (tierw:) keep every row. NALL: class  rows before the dedup. Classes, all on open Fridays unless named:
#   all                      every Long row the trace emitted (the evaluated population)
#   brk:<gate> sector grade  the cascade phase that dropped the row (#2533 sub-gate for breakout)
#   cut:<shadow>             a Dropped_at_top_n row, by its shadow verdict
#   walk:<outcome>           an Admitted row, by what the walk did (Funded, Not_reached, Skipped_<reason>)
#   crowd:gross crowd:net    C*, the would-be-funded crowded-out names under each cash convention (gbc.awk)
#   tier:<grade> tierw:<grade> score:<n>   the post-cascade pool (Admitted + Dropped_at_top_n) by score tier
#   macro:proxy              Friday not open: the screen's book-style breakouts that week (the trace has no names)
FILENAME == ARGV[1] { OP[$1] = $2; next }
FILENAME == ARGV[2] { if ($4 == 1) out("crowd:gross", $1, $2); if ($5 == 1) out("crowd:net", $1, $2); next }
FILENAME == ARGV[3] { out("macro:proxy", $1, $2); next }
{
  if (OP[$1] != 1) next
  out("all", $1, $2)
  if ($3 == "Dropped_at_breakout") out("brk:" $4, $1, $2)
  else if ($3 == "Dropped_at_sector") out("sector", $1, $2)
  else if ($3 == "Dropped_at_grade") out("grade", $1, $2)
  else if ($3 == "Dropped_at_top_n") out("cut:" $9, $1, $2)
  else if ($3 == "Admitted") out("walk:" $7, $1, $2)
  else out("other:" $3, $1, $2)
  if ($3 == "Admitted" || $3 == "Dropped_at_top_n") { out("tier:" $11, $1, $2); out("tierw:" $11, $1, $2); out("score:" $5, $1, $2) }
}
function out(c, d, s,   k, keep) {
  k = c SUBSEP s
  if (substr(c, 1, 6) == "tierw:") keep = 1
  else if (!(k in last) || days(d) - last[k] >= 182) keep = 1
  else keep = 0
  NA[c]++
  if (!keep) return
  last[k] = days(d)
  print c "\t" d "\t" s
}
END { for (c in NA) print c "\t" NA[c] > NALL }
