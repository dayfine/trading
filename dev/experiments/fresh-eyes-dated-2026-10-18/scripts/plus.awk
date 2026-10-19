# plus.awk: prints the date n days after d (default 28). Needs days.awk. Usage: awk -v d=YYYY-MM-DD [-v n=N] -f days.awk -f plus.awk
BEGIN { print civil(days(d) + (n == "" ? 28 : n)) }
