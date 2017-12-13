#!/bin/bash
#
# Borrowed from: https://github.com/lynhines/CDN_work_scripts/blob/master/toplogs.sh
#
# Modified by: Daniel Mikusa <dmikusa@pivotal.io>
#
set -e  # dont add `-o pipefail`, this will cause false errors

printf "Assumes standard GoRouter access log format:\n\n"
# This format is a bit fluid.  Everything after `app_index` is "additional headers" that may or may not be present.  It defaults to what should work for PCF, but may need to be adjusted for other situations.
echo '<Request Host> - [<Start Date>] "<Request Method> <Request URL> <Request Protocol>" <Status Code> <Bytes Received> <Bytes Sent> "<Referer>" "<User-Agent>" <Remote Address> <Backend Address> x_forwarded_for:"<X-Forwarded-For>" x_forwarded_proto:"<X-Forwarded-Proto>" vcap_request_id:<X-Vcap-Request-ID> response_time:<Response Time> app_id:<Application ID> app_index:<Application Index> x_b3_traceid:<zipkin-trace> x_b3_spandid:<zipkin-span> x_b3_parentspanid:<zipkin-spanid>'

apacheRx='^(.*?) - \[(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}).(\d+)(.*?)] "(.*?) (.*?) (.*?)" (\d+) (\d+) (\d+) "(.*?)" "(.*?)" "(.*?)" "(.*?)" x_forwarded_for:"(.*?)" x_forwarded_proto:"(.*?)" vcap_request_id:"(.*?)" response_time:(\d+\.\d+) app_id:"(.*?)" app_index:"(.*?)" x_b3_traceid:"(.*?)" x_b3_spanid:"(.*?)" x_b3_parentspanid:"(.*?)"$'

if [ $# -eq 0 ]; then
    echo "Usage (for top 10):"
    echo "toplogs-gorouter.sh access.log 10"
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
perl -n -e '/'"$apacheRx"'/ && print $13."\r\n"' "$1" | sort | uniq -c | sort -nr

printHeader 'Request Methods'
perl -n -e '/'"$apacheRx"'/ && print $10."\r\n"' "$1" | sort | uniq -c | sort -nr

printHeader 'Top '"$total"' Requests (no query params)'
perl -n -e '/'"$apacheRx"'/ && print $11."\r\n"' "$1" | cut -d '?' -f 1 | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Requests (with query params)'
perl -n -e '/'"$apacheRx"'/ && print $11."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' User Agents'
perl -n -e '/'"$apacheRx"'/ && print $17."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Referrers'
perl -n -e '/'"$apacheRx"'/ && print $16."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Remote Address (LBs)'
perl -n -e '/'"$apacheRx"'/ && print $18."\r\n"' "$1" | cut -d ':' -f 1 | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Backend Address (Cells & Platform VMs)'
perl -n -e '/'"$apacheRx"'/ && print $19."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Client IPs'
perl -n -e '/'"$apacheRx"'/ && print $20."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Destination Hosts'
perl -n -e '/'"$apacheRx"'/ && print $1."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Application UUIDs'
perl -n -e '/'"$apacheRx"'/ && print $24."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Days'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Hours'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Minutes'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5.":".$6."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Seconds'
perl -n -e '/'"$apacheRx"'/ && print $2."/".$3."/".$4." ".$5.":".$6.":".$7."\r\n"' "$1" | sort | uniq -c | sort -nr | head -n "$total"

printHeader 'Top '"$total"' Response Times (secs)'
perl -n -e '/'"$apacheRx"'/ && print $23."\n"' "$1" | xargs printf "%.0f\n" | sort -n | uniq -c | sort -nr | head -n "$total"

exit 0
