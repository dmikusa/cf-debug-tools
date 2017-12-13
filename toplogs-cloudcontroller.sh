#!/bin/bash
#
# Borrowed from: https://github.com/lynhines/CDN_work_scripts/blob/master/toplogs.sh
#
# Modified by: Daniel Mikusa <dmikusa@pivotal.io>
#
set -e  # dont add `-o pipefail`, this will cause false errors

LOGREGEX='^(.*?) - \[(\d{2})\/(\w{3})\/(\d{4}):(\d{2}):(\d{2}):(\d{2}) (.*?)\] "(.*?) (.*?) (.*?)" (\d+) (\d+) "(.*?)" "(.*?)" (.*?) vcap_request_id:(.*?) response_time:(\d+\.\d+)$'

usage () {
    echo "USAGE:"
    echo "toplogs-cloudcontroller.sh [-t|--top 10] <file1> <file2> <file3> ..."
    echo ""
    echo "    -t|--top - defaults to 10, sets the number of results to return"
    echo ""
    echo "NOTES:"
    echo "  Assumes standard CloudController Nginx access log format:"
    echo '    <client ip> - [<date>:<time>] "<method> <request path> <http version>" <status code> <bytes> "<referrer" "<user agent>" <x-forwarded-for> vcap_request_id:<reqest_id> response_time:<response_time>'
    exit 1
}

printHeader () {
    printf "\n--------------------------------------\n"
    printf "  %s" "$1"
    printf "\n--------------------------------------\n\n"
}

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

if [ ${#array[@]} -eq 0 ]; then
    usage
fi

set -- "${POSITIONAL[@]}"

main () {
    printHeader 'Response Codes'
    perl -n -e '/'"$LOGREGEX"'/ && print $12."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr

    printHeader 'Request Methods'
    perl -n -e '/'"$LOGREGEX"'/ && print $9."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr

    printHeader 'Top '"$TOP"' Requests (no query params)'
    perl -n -e '/'"$LOGREGEX"'/ && print $10."\r\n"' <( cat "$@" ) | cut -d '?' -f 1 | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Requests (with query params)'
    perl -n -e '/'"$LOGREGEX"'/ && print $10."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' User Agents'
    perl -n -e '/'"$LOGREGEX"'/ && print $15."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Referrers'
    perl -n -e '/'"$LOGREGEX"'/ && print $14."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Forwarded IPs'
    perl -n -e '/'"$LOGREGEX"'/ && print $16."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Direct Client IP'
    perl -n -e '/'"$LOGREGEX"'/ && print $1."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Days'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Hours'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Minutes'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5.":".$6."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Seconds'
    perl -n -e '/'"$LOGREGEX"'/ && print $2."/".$3."/".$4." ".$5.":".$6.":".$7."\r\n"' <( cat "$@" ) | sort | uniq -c | sort -nr | head -n "$TOP"

    printHeader 'Top '"$TOP"' Response Times (secs)'
    perl -n -e '/'"$LOGREGEX"'/ && print $18."\n"' <( cat "$@" ) | xargs printf "%.0f\n" | sort -n | uniq -c | sort -nr | head -n "$TOP"
}

main "$@"
