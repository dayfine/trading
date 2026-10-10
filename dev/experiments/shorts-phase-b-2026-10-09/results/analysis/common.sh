# Shared paths for the shorts-phase-b analysis scripts. Sourced, not run. Run every script from the repo root.
#   R        committed per-cell artifacts (trades.csv, equity_curve.csv, summary.sexp, ...)
#   AUD_A    lane-A sweep output holding v0's trade_audit.sexp (not committed, ~3 MB per cell)
#   AUD_B    lane-B sweep output holding v1's trade_audit.sexp
#   DATA     the host CSV store: <DATA>/<first char>/<last char>/<SYM>/data.csv (bars)
#   DIVROOT  where dividends.csv was staged for the run (the run tree); falls back to DATA, whose files the
#            launcher copied there (byte-identical for all 198 traded symbols, checked 2026-10-10)
#   WORK     scratch directory for the flattened inputs (prep.sh writes it)
R=${R:-dev/experiments/shorts-phase-b-2026-10-09/results}
AUD_A=${AUD_A:-.sweep-output/shorts-phase-b}
AUD_B=${AUD_B:-.sweep-output/shorts-phase-b-v1}
DATA=${DATA:-data}
if [ -z "${DIVROOT:-}" ]; then
  if [ -d .claude/worktrees/sweep-spb-B/trading/test_data/A ]; then DIVROOT=.claude/worktrees/sweep-spb-B/trading/test_data
  else DIVROOT=$DATA; fi
fi
DTB3=${DTB3:-trading/test_data/macro/tbill_3m_dtb3.csv}
SPY_CSV=${SPY_CSV:-$DATA/S/Y/SPY/data.csv}
WORK=${WORK:-${TMPDIR:-/tmp}/spb-analysis}
CELLS=${CELLS:-"v0-26-s0 v0-26-s1 v0-26-s2 v1-26-s0 v1-26-s1 v1-26-s2"}
_shard() { printf '%s' "$1" | awk '{ printf "%s/%s", toupper(substr($0, 1, 1)), toupper(substr($0, length($0), 1)) }'; }
md5_of_stdin() { if command -v md5 >/dev/null 2>&1; then md5 -q; else md5sum | cut -d' ' -f1; fi; }
bars_of() { printf '%s/%s/%s/data.csv' "$DATA" "$(_shard "$1")" "$1"; }
divs_of() {
  if [ -f "$DIVROOT/$(_shard "$1")/$1/dividends.csv" ]; then printf '%s/%s/%s/dividends.csv' "$DIVROOT" "$(_shard "$1")" "$1"
  else printf '%s/%s/%s/dividends.csv' "$DATA" "$(_shard "$1")" "$1"; fi
}
audit_of() { case $1 in v0-*) printf '%s/%s-v12-trade_audit.sexp' "$AUD_A" "$1" ;; *) printf '%s/%s-v12-trade_audit.sexp' "$AUD_B" "$1" ;; esac; }
