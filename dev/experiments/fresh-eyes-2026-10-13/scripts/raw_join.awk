# raw_join.awk: one CSV row per raw reader answer: file name (cut-attempt), answer text with commas kept inside quotes.
# Usage: awk -f raw_join.awk <raw dir>/*.txt > decisions.csv
BEGIN { print "call,answer" }
FNR == 1 { if (buf != "") out(); f = FILENAME; sub(/.*\//, "", f); sub(/\.txt$/, "", f); buf = "" }
{ buf = buf (buf == "" ? "" : " ") $0 }
END { if (f != "") out() }
function out(   b) { b = buf; gsub(/"/, "\"\"", b); printf "%s,\"%s\"\n", f, b; buf = "" }
