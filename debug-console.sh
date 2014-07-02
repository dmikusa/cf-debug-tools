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
# Install script for websocketd in a CloudFoundry environment.
#
#  Author:  Daniel Mikusa <dmikusa@gopivotal.com>
#    Date:  2014-02-09
# --------------------------------------------------------------

# Download websocketd, supports Mac OSX or Linux.  Mac is supported for development.
if [ ! -f "./websocketd" ]; then
    URL_BASE="https://github.com/joewalnes/websocketd/releases/download/v0.2.9"
    if [ `uname -s` == 'Darwin' ]; then
        ARCHIVE="websocketd-0.2.9-darwin_amd64.zip"
    fi
    if [ `uname -s` == 'Linux' ]; then
        if [ `uname -m` == 'x86_64' ]; then
            ARCHIVE="websocketd-0.2.9-linux_amd64.zip"
        else
            ARCHIVE="websocketd-0.2.9-linux_386.zip"
        fi
    fi
    # Download websocketd
    DOWNLOAD_URL="$URL_BASE/$ARCHIVE"
    echo "Downloading websocketd from [$DOWNLOAD_URL]"
    curl -s -L -O "$DOWNLOAD_URL"
    # Extract files
    unzip -p "$ARCHIVE" websocketd > websocketd
    chmod 755 websocketd
    rm "$ARCHIVE"
fi

# Create a bash script that websocketd will use to run
cat > bash.sh <<EOF
#!/bin/bash
while read LINE
do
    eval "\$LINE"
done
EOF
chmod 755 bash.sh

# Start web socketd
echo "Running websocketd on port [${PORT:-4443}]..."
./websocketd --port=${PORT:-4443} --dir=. --devconsole

# Clean Up
rm websocketd
rm bash.sh
