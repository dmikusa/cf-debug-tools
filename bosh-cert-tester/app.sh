#!/bin/bash
#
# Help with validation of Bosh deployed certs
#
# Performs the following tests:
#  - dumps the individual cert files that are deployed by Bosh
#  - dumps the CA cert bundle, which should include the Bosh deployed certs
#  - makes HTTPS connections to the defined list of URLs using the CA cert bundle
#  - makes TCP/TLS connections to the defined list of host:ports using the CA cert bundle
#
# All output is written to STDOUT, which should show up in `cf logs`
#   or
# `scp -P 2222 -oUser=cf:$(cf app bosh-cert-tester --guid)/0 "$(cf curl /v2/info | jq -r .app_ssh_endpoint | cut -d ':' -f 1)":./app/output.txt ./`
#   to download the log file
#
set -euo pipefail

function slow_print {
    while read -r LINE; do
        echo "$LINE"
        sleep 0.01  # delay slow we don't blast loggregator with output
    done
}

function dump_bosh_deployed_certs {
    echo 'Dumping Bosh Deployed Certs...'
    for CERT in /usr/local/share/ca-certificates/*; do 
        echo "Found [$CERT]" | slow_print
        openssl x509 -in "$CERT" -text -noout
    done
    echo 'Done!'
    echo ''
    echo ''
}

function dump_ca_cert_bundle {
    echo 'Dumping the CA Cert bundle [/etc/ssl/certs/ca-certificates.crt]...'
    openssl crl2pkcs7 -nocrl -certfile /etc/ssl/certs/ca-certificates.crt | openssl pkcs7 -print_certs -text
    echo 'Done!'
    echo ''
    echo ''
}

function send_curl_requests {
    echo 'Attempting to make connections to defined HTTP end points...'
    for URL in $(jq -r .[] https-endpoints.json); do
        echo ''
        echo "Trying URL [$URL]..."
        # flip stderr & stdout, cause we only want stderr
        if ! curl -vv -s -S "$URL" 3>&1 1>&2 2>&3 3>&- 2>/dev/null
        then
            echo ''
            echo "Trying again but ignoring the cert error to get more details"
        # flip stderr & stdout, cause we only want stderr
            curl -k -vv -s -S "$URL" 3>&1 1>&2 2>&3 3>&- 2>/dev/null
            echo ''
        fi
        echo ''
    done
    echo 'Done!'
    echo ''
    echo ''
}

function send_openssl_sclient_requests {
    echo 'Attempting to make connections to defined TCP end points...'
    for HOST in $(jq -r .[] tcp-endpoints.json); do
        echo ''
        echo ''
        echo "Trying TCP [$HOST]..."
        echo 'Q' | openssl s_client -connect "$HOST"
        echo ''
        echo ''
    done
    echo 'Done!'
    echo ''
    echo ''
}

function wait_forever {
    # wait forever so app is not listed as "crashed"
    while :; do
        sleep 500
    done
}

function main {
    { dump_bosh_deployed_certs; \
      dump_ca_cert_bundle; \
      send_curl_requests; \
      send_openssl_sclient_requests; } > output.txt
    slow_print < output.txt
    wait_forever
}

main
