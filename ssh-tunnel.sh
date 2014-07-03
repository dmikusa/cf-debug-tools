#!/bin/bash
#  Helper script for setting up an SSH Tunnel out of your CF app
#
#  Author:  Daniel Mikusa <dmikusa@gopivotal.com>
#    Date:  7-3-2014
#
set -e

# Look for .ssh directory in application, move it to /home/vcap/.ssh
find /home/vcap/app -name .ssh -type d -exec mv -n {} /home/vcap \;
if [ ! -d /home/vcap/.ssh ]; then
    echo "You need to include a '.ssh' directory with your application!"
    echo "This needs to contain the private and public key for the user"
    echo "that will connect to your SSH server."
    echo
    exit -1
fi

# Find and fix permissions on private keys
for FILE in /Users/danielmikusa/Downloads/node-test/.ssh/*; do
    if [[ "$FILE" == *.pub ]]; then
        PUB_KEY=$FILE
        PRIV_KEY="$(dirname "$FILE")/$(basename "$FILE" .pub)"
        break
    fi
done
echo "Found public key [$PUB_KEY] and private key [$PRIV_KEY]."
chmod 600 "$PRIV_KEY"

# Calculate local port
#  This checks env var LOCAL_BASE_PORT and increments the instance index onto it
if [ "$LOCAL_BASE_PORT" == "" ]; then
    export LOCAL_BASE_PORT=31337
fi
LOCAL_PORT=$(python -c "import json, os; print json.loads(os.environ['VCAP_APPLICATION'])['instance_index'] + int(os.environ['LOCAL_BASE_PORT'])")

# Connects via SSH to $PUBLIC_SERVER (<user@>host<:port>) and opens a reverse tunnel.
#   The tunnel connects $LOCAL_PORT on the public server to $SERVICE_PORT 
#   in the application container.
#   $LOCAL_PORT is calculated based on $LOCAL_BASE_PORT, which is user defined.
ssh -i "$PRIV_KEY" -oStrictHostKeyChecking=no -f -N -T -R"$LOCAL_PORT:localhost:$SERVICE_PORT" "$PUBLIC_SERVER"
