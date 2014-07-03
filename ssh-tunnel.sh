#!/bin/bash
#  Helper script for setting up an SSH Tunnel out of your CF app
#
#  Author:  Daniel Mikusa <dmikusa@gopivotal.com>
#    Date:  7-3-2014
#
set -e

# Look for .ssh directory in application, move it to /home/vcap/.ssh
SSH_FOLDER=$(find /home/vcap/app -name .ssh -type d | head -n 1)
if [ "$SSH_FOLDER" == "" ]; then
    echo
    echo "You need to include a '.ssh' directory with your application!"
    echo "This needs to contain the private and public key for the user"
    echo "that will connect to your SSH server."
    echo
    exit -1
elif [ "$SSH_FOLDER" != "/home/vcap/.ssh" ]; then
    echo "Moved [$SSH_FOLDER] to /home/vcap/.ssh, where it's expected."
    mv "$SSH_FOLDER" /home/vcap
else
    echo "SSH Folder alread exists at [$SSH_FOLDER]"
fi

# Find and fix permissions on private keys
for FILE in /Users/danielmikusa/Downloads/node-test/.ssh/*; do
    if [[ "$FILE" == *.pub ]]; then
        PUB_KEY=$FILE
        PRIV_KEY="$(dirname "$FILE")/$(basename "$FILE" .pub)"
        break
    fi
done
if [ "$PUB_KEY" == "" ] || [ "$PRIV_KEY" == "" ]; then
    echo "Failed to find public or private keys."
    echo "Found -> [$PUB_KEY] [$PRIV_KEY]"
    exit -1
else
    echo "Found public key [$PUB_KEY] and private key [$PRIV_KEY]."
    chmod 600 "$PRIV_KEY"
fi

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
