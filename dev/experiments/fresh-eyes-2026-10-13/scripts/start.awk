# Fresh-eyes stepper: the first cut for a symbol (step.sh init auto). Usage: awk -F, -f days.awk -f start.awk <weekly.csv>
# The first Friday at or after 2000-01-07 on which the 30-week MA exists (30 weekly bars), so the first page a
# reader sees has an MA on it.
BEGIN { FS = "," }
FNR > 1 && $7 != "" && $1 >= "2000-01-07" { print $1; found = 1; exit }
END { if (!found) print "none" }
