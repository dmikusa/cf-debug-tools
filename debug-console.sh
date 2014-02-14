#!/bin/bash
#
# Install script for websocketd in a CloudFoundry environment.
#
#  Author:  Daniel Mikusa <dmikusa@gopivotal.com>
#    Date:  2014-02-09
#

# Download websocketd, supports Mac OSX or Linux.  Mac is supported for development.
if [ ! -f "./websocketd" ]; then
    if [ `uname -s` == 'Darwin' ]; then
        DOWNLOAD_URL="http://download.websocketd.com/releases/websocketd/0.2.8/darwin_amd64/websocketd"
    fi
    if [ `uname -s` == 'Linux' ]; then
        if [ `uname -m` == 'x86_64' ]; then
            DOWNLOAD_URL="http://download.websocketd.com/releases/websocketd/0.2.8/linux_amd64/websocketd"
        else
            DOWNLOAD_URL="http://download.websocketd.com/releases/websocketd/0.2.8/linux_386/websocketd"
        fi
    fi
    # Download websocketd
    curl -s -L -O "$DOWNLOAD_URL"
    chmod 755 websocketd
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
./websocketd --port=$PORT --dir=. --devconsole
