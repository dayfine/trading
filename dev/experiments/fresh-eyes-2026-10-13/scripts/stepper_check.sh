#!/bin/sh
# stepper_check.sh: sim.awk on hand-made daily fixtures (flat at 10, a few days overridden). Exit 1 on any failure.
# Cases: buy-stop fill on a gap open; a limit blocks a gap-open day; short fill; the fill day's low is not checked
# against the stop; stop raise accepted and stop lower rejected; a long stop above the trigger rejected; the
# 8-week rest (flagged, cancelled on none, re-issue restarts the clock); the 4-week and fill-week checkpoints;
# exit at the next open; the end-of-run mark. Run from the repo root.
set -e
S=dev/experiments/fresh-eyes-2026-10-13/scripts
T=${TMPDIR:-/tmp}/fe-stepcheck-$$; mkdir -p "$T"; fail=0
awk -v from=2019-12-02 -v to=2020-12-31 -v base=300 -v over= -f $S/days.awk -f $S/fixture.awk > "$T/spy.csv"
printf 'week,open,high,low,close,vol_base,ma30,rs,raw_close,split_index\n2019-12-27,10,10,10,10,1,10,0,10,1\n' > "$T/wk.csv"
state0() {  # state0 <cut> [<pos> <edate> <epx> <stop>]
  printf 'sym=FIX\ncut=%s\npos=%s\nedate=%s\nepx=%s\nstop=%s\nord=none\ntrig=\nlim=\nostop=\nplaced=\ndue=0\nxpend=0\nstatus=open\nmsg=\n' \
    "$1" "${2:-none}" "$3" "$4" "$5" > "$T/state"
}
run() {  # run <over> <decision text> [end]: sim output in $T/out
  awk -v from=2019-12-02 -v to=2020-12-31 -v base=10 -v over="$1" -f $S/days.awk -f $S/fixture.awk > "$T/d.csv"
  printf '%s\n' "$2" | tr '|' '\n' > "$T/dec.raw"; sh $S/decision.sh "$T/dec.raw" > "$T/dec"
  awk -F, -v end="${3:-2026-06-26}" -f $S/days.awk -f $S/sim.awk "$T/state" "$T/dec" "$T/wk.csv" "$T/spy.csv" "$T/d.csv" > "$T/out"
}
has() {  # has <label> <grep -x pattern>
  if grep -qx -- "$2" "$T/out"; then echo "ok    $1"; else echo "FAIL  $1: no line '$2'"; sed 's/^/        /' "$T/out"; fail=1; fi
}
adopt() { grep -v -e '^TRADE,' -e '^LOG,' "$T/out" > "$T/state"; }

# 1. buy-stop, gap open above the trigger: fills at the open; next checkpoint = the fill week's Friday.
state0 2020-01-03; run "2020-01-06:12/12.5/11.8/12" "action=buy_stop|trigger=11|stop=9"
has "gap-open buy fills at the open" "epx=12"; has "fill date" "edate=2020-01-06"; has "fill-week checkpoint" "cut=2020-01-10"
# 2. a limit blocks the gap-open day; the next day fills at max(open, trigger).
state0 2020-01-03; run "2020-01-06:12/12.5/11.8/12;2020-01-07:11.2/11.6/11.1/11.4" "action=buy_stop|trigger=11|limit=11.5|stop=9"
has "limit blocks a gap-open day" "edate=2020-01-07"; has "fills at the open above the trigger" "epx=11.2"
# 3. short-stop fill at min(open, trigger).
state0 2020-01-03; run "2020-01-08:9.5/9.6/8.8/8.9" "action=short_stop|trigger=9|stop=10.5"
has "short fills at the trigger" "epx=9"; has "short position" "pos=short"
# 4. the fill day's low is below the stop but is not checked; the next day's low stops it at the stop.
state0 2020-01-03; run "2020-01-06:10.5/11.5/9.5/11;2020-01-07:11/11.2/9.8/10" "action=buy_stop|trigger=11|stop=10"
has "stopped the day after the fill" "TRADE,FIX,long,2020-01-06,11.000000,2020-01-07,10.000000,stop,-0.090909,0.000000,-0.090909"
has "flat after the stop" "pos=none"
# 5. stop raise accepted; lower rejected.
state0 2020-01-03 long 2019-12-16 8 7; run "" "action=set_stop|stop=8.5"
has "stop raise accepted" "stop=8.5"
state0 2020-01-03 long 2019-12-16 8 7; run "" "action=set_stop|stop=6.5"
has "stop lower rejected" "REJECT,a long stop may not be lowered"
state0 2020-01-03 short 2019-12-16 12 13; run "" "action=set_stop|stop=13.5"
has "short stop raise rejected" "REJECT,a short stop may not be raised"
# 6. a long stop at or above the trigger is rejected.
state0 2020-01-03; run "" "action=buy_stop|trigger=11|stop=11.5"
has "stop above trigger rejected" "REJECT,a long stop must be below the trigger"
# 7. 4-week checkpoint with no event; 8-week rest flagged, cancelled on none; re-issue restarts the clock.
state0 2020-01-03; run "" "action=buy_stop|trigger=20|stop=9"
has "4-week checkpoint" "cut=2020-01-31"; has "not yet due" "due=0"; adopt
run "" "action=none"; has "8-week checkpoint" "cut=2020-02-28"; has "rest flagged" "due=1"; adopt
cp "$T/state" "$T/state.due"
run "" "action=none"; has "unconfirmed order cancelled" "ord=none"
cp "$T/state.due" "$T/state"; run "" "action=buy_stop|trigger=20|stop=9"
has "re-issue restarts the clock" "placed=2020-02-28"; has "re-issued order rests" "ord=buy_stop"
# 8. exit fills at the next day's open.
state0 2020-01-03 long 2019-12-16 8 7; run "2020-01-06:10.4/10.6/10.2/10.5" "action=exit"
has "exit at the next open" "TRADE,FIX,long,2019-12-16,8.000000,2020-01-06,10.400000,exit,0.300000,0.000000,0.300000"
# 9. the run's end marks an open position to the last close and finishes.
state0 2020-01-03 long 2019-12-16 8 7; run "" "action=none" 2020-01-17
has "end mark" "TRADE,FIX,long,2019-12-16,8.000000,2020-01-17,10.000000,open_at_end,0.250000,0.000000,0.250000"
has "run finished" "status=done"
# 10. a JSON decision parses the same as key=value.
state0 2020-01-03; run "2020-01-06:12/12.5/11.8/12" '{"stage":2,"action":"buy_stop","trigger":11,"stop":9,"reason":"base, 2x vol"}'
has "JSON decision" "epx=12"
rm -rf "$T"
[ $fail = 0 ] && echo "stepper check: PASS" || { echo "stepper check: FAIL"; exit 1; }
