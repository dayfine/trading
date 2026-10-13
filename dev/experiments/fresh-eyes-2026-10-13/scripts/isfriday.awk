# Prints 1 if -v c=YYYY-MM-DD is a Friday, else 0. Usage: awk -v c=... -f days.awk -f isfriday.awk
BEGIN { print (friday(days(c)) == days(c)) ? 1 : 0 }
