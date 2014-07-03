#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing,
#  software distributed under the License is distributed on an
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#  KIND, either express or implied.  See the License for the
#  specific language governing permissions and limitations
#  under the License.

# --------------------------------------------------------------
# Helper script for setting up an SSH Tunnel out of your CF app
#
#  Author:  Daniel Mikusa <dmikusa@gopivotal.com>
#    Date:  7-3-2014
# --------------------------------------------------------------
set -e

# Look for .ssh directory in application, move it to /home/vcap/.ssh
SSH_FOLDER=$(find /home -name .ssh -type d | head -n 1)
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
for FILE in /home/vcap/.ssh/*; do
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
    echo "No LOCAL_BASE_PORT defined, defaulting to 31337."
fi
LOCAL_PORT=$(python -c "import json, os; print json.loads(os.environ['VCAP_APPLICATION'])['instance_index'] + int(os.environ['LOCAL_BASE_PORT'])")

# Make sure $SERVICE_PORT is set, default to $PORT
if [ "$SERVICE_PORT" == "" ]; then
    export SERVICE_PORT=$PORT
    echo "No SERVICE_PORT defined, defaulting to application on [$PORT]"
fi

# Make sure PUBLIC_SERVER is defined
if [ "$PUBLIC_SERVER" == "" ]; then
    echo
    echo "You must define the location of your public server.  Set this in the"
    echo "environment variable PUBLIC_SERVER. <user@>host<:port>"
    echo
    exit -1
fi

# Connects via SSH to $PUBLIC_SERVER (<user@>host<:port>) and opens a reverse tunnel.
#   The tunnel connects $LOCAL_PORT on the public server to $SERVICE_PORT 
#   in the application container.
#   $LOCAL_PORT is calculated based on $LOCAL_BASE_PORT, which is user defined.
ssh -i "$PRIV_KEY" -oStrictHostKeyChecking=no -f -N -T -R"$LOCAL_PORT:localhost:$SERVICE_PORT" "$PUBLIC_SERVER"
echo "Connected!  To access go to localhost:$LOCAL_PORT on your public server [$PUBLIC_SERVER]."

#TODO: watch SSH tunnel to see if it goes down.  If it does, try restarting.
