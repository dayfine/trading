# Weighted long-trade rubric. References are sections of
# docs/design/weinstein-book-reference.md; 52 weeks is the #3140 policy,
# not a numeric rule in the book. Keep weights and citations in this table.
def rules: [
  {id:1, name:"Stage 2 with rising 30-week MA", weight:2, section:"4.1", evidence:"Replay stage can disprove Stage 2; MA slope is not joined."},
  {id:2, name:"At least 52 weeks of history", weight:1, section:"4.3", evidence:"History length is not joined; 52-week minimum is pack policy (#3140)."},
  {id:3, name:"Screen-week volume ≥ 2×", weight:2, section:"4.2", evidence:"vr: screening-week volume ratio."},
  {id:4, name:"Fill-week volume ≥ 2× or quiet pullback", weight:1, section:"4.2", evidence:"fvr ≥ 2 confirms; quiet-pullback context is not joined."},
  {id:5, name:"RS positive", weight:1, section:"4.4", evidence:"rs: audit decision-time RS trend."},
  {id:6, name:"Overhead resistance graded, not C", weight:1, section:"4.3", evidence:"Overhead grade is not joined; aGrade is a composite cascade grade."},
  {id:7, name:"Fill macro week not Bearish", weight:2, section:"2.1", evidence:"mE: last macro screen strictly before fill, not aMacro."},
  {id:8, name:"Sector gate passed", weight:1, section:"3.1", evidence:"Sector decision is not joined."},
  {id:9, name:"Fill at/above trigger and within limit", weight:1, section:"4.7", evidence:"Negative fvt or audited unfaithful fill disproves it; Market fills also report faithful=true, so cannot prove it."},
  {id:10, name:"Structural stop, no fallback", weight:1, section:"5.1", evidence:"sfk: Support_floor versus Buffer_fallback."},
  {id:11, name:"Installed stop within 15% of fill", weight:2, section:"5.1", evidence:"isd: installed distance, never screening sid. 15% is the pack policy."},
  {id:12, name:"Stop hit, or badly lagging rotation", weight:1, section:"5.6", evidence:"Reported stop_loss passes; exit-time weakness for laggard_rotation is not joined. See also §5.7."},
  {id:13, name:"No Stage-4 hold", weight:2, section:"1", evidence:"s4w and holdW from weekly stage replay; any observed Stage-4 week fails."}
];
def num: type == "number";
def status($x): if $x == null then "n/a" elif $x then "pass" else "fail" end;
# Conventional percentage bands, inclusive at 90/80/70/60; no E band.
def grade($score):
  if $score == null then "n/a" elif $score >= 90 then "A"
  elif $score >= 80 then "B" elif $score >= 70 then "C"
  elif $score >= 60 then "D" else "F" end;
def known_stage: . == "Stage1" or . == "Stage2" or . == "Stage3" or . == "Stage4";
def check($i):
  if .side != "LONG" then null
  elif $i == 1 then if (.rsE | known_stage) and .rsE != "Stage2" then false else null end
  elif $i == 3 then if (.vr | num) and .vr >= 0 then .vr >= 2 else null end
  elif $i == 4 then if (.fvr | num) and .fvr >= 2 then true else null end
  elif $i == 5 then
    (.rs // "") as $rs
      | if (["Pos_rising","Pos_flat","Pos_declining","Bullish_xover"] | index($rs)) != null then true
        elif (["Neg_improving","Neg_declining","Bearish_xover"] | index($rs)) != null then false else null end
  elif $i == 7 then if .mE == "Bearish" then false elif .mE == "Bullish" or .mE == "Neutral" then true else null end
  elif $i == 9 then if (.fvt | num) and (.fvt < -0.0001 or .faithful == false) then false else null end
  elif $i == 10 then if .sfk == "Support_floor" then true elif .sfk == "Buffer_fallback" then false else null end
  elif $i == 11 then if (.isd | num) then .isd >= 0 and .isd <= 0.15 else null end
  elif $i == 12 then
    if .trig == "stop_loss" then true
    elif .trig == "laggard_rotation" or (.trig // "") == "" then null
    elif (.trig as $trig | ["force_liquidation","margin_call","delisted","liquidity_exit","extension_stop","stage3_force_exit","stale_force_exit"] | index($trig)) != null then false
    else null end
  elif $i == 13 then
    if (.s4w | num) and .s4w > 0 then false
    elif (.s4w | num) and .s4w == 0 and (.holdW | num) and .holdW > 0 then true else null end
  else null end;
def row:
  . as $t
  | [rules[] as $r | $r + {status: ($t | check($r.id) | status(.))}] as $checks
  | ([$checks[] | select(.status != "n/a") | .weight] | add // 0) as $possible
  | ([$checks[] | select(.status == "pass") | .weight] | add // 0) as $earned
  | (if $possible > 0 then 100 * $earned / $possible else null end) as $score
  | {id, sym, ed, xd, checks: ($checks | map({id,status})), possible: $possible, earned: $earned,
     score: $score, grade: grade($score), failed: [$checks[] | select(.status == "fail") | .id],
     fvr: (if .side == "LONG" and (.fvr | num) and .fvr >= 0 then .fvr else null end),
     detectors: {
       healthy: (if .side != "LONG" then null elif .trig == "stop_loss" then false
                 elif (.rsX | known_stage) and .rsX != "Stage2" then false else null end),
       above: (if .side != "LONG" or (.fvt | num | not) then null
               elif .faithful == false and .fvt > 0 then true
               elif .fvt < 0 then false else null end),
       history: null}};
[.[] | row] as $rows
| {available:true, rules:rules, total_weight:(rules | map(.weight) | add), rows:$rows,
   grades: (["A","B","C","D","F","n/a"] | map(. as $g | {key:$g,value:([$rows[] | select(.grade == $g)] | length)}) | from_entries),
   failures: [rules[] as $r | $r + {
     count: ([$rows[].checks[] | select(.id == $r.id and .status == "fail")] | length),
     known: ([$rows[].checks[] | select(.id == $r.id and .status != "n/a")] | length)}]}
