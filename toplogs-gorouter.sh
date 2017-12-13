#!/bin/bash
#
# Borrowed from: https://github.com/lynhines/CDN_work_scripts/blob/master/toplogs.sh
#
# Modified by: Daniel Mikusa <dmikusa@pivotal.io>
#
set -e  # dont add `-o pipefail`, this will cause false errors

LOGREGEX='^(.*?) - \[(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}).(\d+)(.*?)] "(.*?) (.*?) (.*?)" (\d+) (\d+) (\d+) "(.*?)" "(.*?)" "(.*?)" "(.*?)" x_forwarded_for:"(.*?)" x_forwarded_proto:"(.*?)" vcap_request_id:"(.*?)" response_time:(\d+\.\d+) app_id:"(.*?)" app_index:"(.*?)" x_b3_traceid:"(.*?)" x_b3_spanid:"(.*?)" x_b3_parentspanid:"(.*?)"$'

# parse out args
#  - https://stackoverflow.com/a/14203146/1585136
TOP=10
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -t|--top)
        TOP="$2"
        shift
        shift
        ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}"

usage () {
    echo "USAGE:"
    echo "toplogs-gorouter.sh [-t|--top 10] <file1> <file2> <file3> ..."
    echo ""
    echo "    -t|--top - defaults to 10, sets the number of results to return"
    echo ""
    echo "NOTES:"
    echo "  Assumes standard GoRouter access log format:"
    echo '    <Request Host> - [<Start Date>] "<Request Method> <Request URL> <Request Protocol>" <Status Code> <Bytes Received> <Bytes Sent> "<Referer>" "<User-Agent>" <Remote Address> <Backend Address> x_forwarded_for:"<X-Forwarded-For>" x_forwarded_proto:"<X-Forwarded-Proto>" vcap_request_id:<X-Vcap-Request-ID> response_time:<Response Time> app_id:<Application ID> app_index:<Application Index> x_b3_traceid:<zipkin-trace> x_b3_spandid:<zipkin-span> x_b3_parentspanid:<zipkin-spanid>'
    echo ""
    echo "  It's also worth noting that this format is fluid.  Everything after \`app_index\` is \"additional headers\" that may or may not be present.  It defaults to what should work for PCF, but may need to be adjusted for other situations."
    exit 1
}

printHeader () {
    printf "\n--------------------------------------\n"
    printf "%s" "$1"
    printf "\n--------------------------------------\n\n"
}

main () {
    printHeader 'Response Codes'
    perl -n -e '/'"$LOGREGEX"'/ && print $13."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr

    printHeader 'Request Methods'
    perl -n -e '/'"$LOGREGEX"'/ && print $10."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr

    printHeader 'Top '"$TOP"' Requests (no query params)'
    perl -n -e '/'"$LOGREGEX"'/ && print $11."\r\n"' <( cat "$@" ) | cut -d '?' -f 1 | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Requests (with query params)'
    perl -n -e '/'"$LOGREGEX"'/ && print $11."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' User Agents'
    perl -n -e '/'"$LOGREGEX"'/ && print $17."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Referrers'
    perl -n -e '/'"$LOGREGEX"'/ && print $16."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Remote Address (LBs)'
    perl -n -e '/'"$LOGREGEX"'/ && print $18."\r\n"' <( cat "$@" ) | cut -d ':' -f 1 | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Backend Address (Cells & Platform VMs)'
    perl -n -e '/'"$LOGREGEX"'/ && print $19."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Client IPs'
    perl -n -e '/'"$LOGREGEX"'/ && print $20."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Destination Hosts'
    perl -n -e '/'"$LOGREGEX"'/ && print $1."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Application UUIDs'
    perl -n -e '/'"$LOGREGEX"'/ && print $24."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Days'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Hours'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Minutes'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5.":".$6."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Seconds'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5.":".$6.":".$7."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Response Times (secs)'
    perl -n -e '/'"$LOGREGEX"'/ && print $23."\n"' <( cat "$@" ) | xargs printf "%.0f\n" | sort -n | uniq -c | sort -nr | head -n "$TOP"
}

main "$@"
