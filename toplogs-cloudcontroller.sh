#!/bin/bash
#
# Borrowed from: https://github.com/lynhines/CDN_work_scripts/blob/master/toplogs.sh
#
# Modified by: Daniel Mikusa <dmikusa@pivotal.io>
#
set -e  # dont add `-o pipefail`, this will cause false errors

printf "Assumes standard CloudController Nginx access log format:\n\n"
echo '<client ip> - [<date>:<time>] "<method> <request path> <http version>" <status code> <bytes> "<referrer" "<user agent>" <x-forwarded-for> vcap_request_id:<reqest_id> response_time:<response_time>'

apacheRx='^(.*?) - \[(\d{2})\/(\w{3})\/(\d{4}):(\d{2}):(\d{2}):(\d{2}) (.*?)\] "(.*?) (.*?) (.*?)" (\d+) (\d+) "(.*?)" "(.*?)" (.*?) vcap_request_id:(.*?) response_time:(\d+\.\d+)$'

if [ $# -eq 0 ]; then
    echo "Usage (for top 10):"
    echo "toplogs-cloudcontroller.sh access.log 10"
    exit 1
fi

if [ -z "$2" ]
then
	total=10
else
	total=$2
fi

printHeader () {
    printf "\n--------------------------------------\n"
    printf "%s" "$1"
    printf "\n--------------------------------------\n\n"
}

printHeader 'Response Codes'
perl -n -e '/'"$apacheRx"'/ && print $12."\r\n"' "$1" | sort | uniq -c | sort -nr

printHeader 'Request Methods'
perl -n -e '/'"$apacheRx"'/ && print $9."\r\n"' "$1" | sort | uniq -c | sort -nr

printHeader 'Top '"$total"' Requests (no query params)'
perl -n -e '/'"$apacheRx"'/ && print $10."\r\n"' "$1" | cut -d '?' -f 1 | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Requests (with query params)'
perl -n -e '/'"$apacheRx"'/ && print $10."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' User Agents'
perl -n -e '/'"$apacheRx"'/ && print $15."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Referrers'
perl -n -e '/'"$apacheRx"'/ && print $14."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Forwarded IPs'
perl -n -e '/'"$apacheRx"'/ && print $16."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Direct Client IP'
perl -n -e '/'"$apacheRx"'/ && print $1."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Days'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Hours'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Minutes'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5.":".$6."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Seconds'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5.":".$6.":".$7."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Response Times (secs)'
perl -n -e '/'"$apacheRx"'/ && print $18."\n"' "$1" | xargs printf "%.0f\n" | sort -n | uniq -c | sort -nr | head -n "$total"

exit 0
