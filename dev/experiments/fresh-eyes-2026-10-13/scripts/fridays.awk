# Every Friday from FROM to TO (inclusive), one per line. Usage: awk -v from=... -v to=... -f days.awk -f fridays.awk
BEGIN { for (z = friday(days(from)); z <= days(to); z += 7) print civil(z) }
