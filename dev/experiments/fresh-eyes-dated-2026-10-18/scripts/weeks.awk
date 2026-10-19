# weeks.awk: whole weeks from a to b. Needs days.awk. Usage: awk -v a=D1 -v b=D2 -f days.awk -f weeks.awk
BEGIN { print int((days(b) - days(a)) / 7) }
