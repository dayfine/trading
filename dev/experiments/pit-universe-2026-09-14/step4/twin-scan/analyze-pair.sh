#!/bin/sh
# Usage: analyze-pair.sh <pair-tag>  → <tag>/to-drop-pairs.txt ("SURVIVOR DROPPED overlap match"), rule:
# direct edge overlap>=200 & match>=0.95; survivor not a hub (>4 legs = degenerate flat-series class, #2823);
# dropped leg not in the restored false-legs list; both legs currently indexed in the manifest.
t=$1; cd /tmp/twin-scan/$t || exit 1
awk '/^  survivor/{s=$2} /^    [A-Z0-9]/{print s, $1, $2, $3}' rename_twin_report.txt | sed 's/(overlap=//; s/,//; s/match=//; s/)//' > pairs.txt
awk '{print $1}' pairs.txt | sort | uniq -c | awk '$1>4{print $2}' > hubs.txt
LC_ALL=C sort -u /tmp/pit-fetch/specs/false-legs.txt > /tmp/twin-scan/false-legs.sorted
awk '$3>=200 && $4>=0.95' pairs.txt | grep -v -w -f hubs.txt | while read s d o m; do
  grep -qx "$s" ../manifest-syms.txt && grep -qx "$d" ../manifest-syms.txt && ! grep -qx "$d" /tmp/twin-scan/false-legs.sorted && echo "$s $d $o $m"; done > to-drop-pairs.txt
printf "%s: groups=%s edges=%s hubs=[%s] to-drop=%s\n" "$t" "$(grep -c '^  survivor' rename_twin_report.txt)" "$(wc -l < pairs.txt | tr -d ' ')" "$(tr '\n' ' ' < hubs.txt)" "$(wc -l < to-drop-pairs.txt | tr -d ' ')"
