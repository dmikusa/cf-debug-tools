# Debug Tools for CloudFoundry

This project is a collection of scripts that can be used to help troubleshoot applications deployed to CloudFoundry.  See each script for more details.

## Debug Console

This script downloads and installs [websocketd](https://github.com/joewalnes/websocketd).  It simply automates the steps described [here](http://www.iamjambay.com/2013/12/send-interactive-commands-to-cloud.html).

### Suggested Usage

The easiest way to use this script is with the ```--command``` argument of cf.

Ex:

```
cf push -c 'curl -s https://raw.githubusercontent.com/dmikusa-pivotal/cf-debug-tools/master/debug-console.sh | bash' ...
```

This will instruct CF to run this command instead of your application.  Once run, the script will download websocketd and enable to you connect to it instead.  To connect access the application in your browser.  From there you'll see the web console and be able to connect.

Ex:

```
https://<host>.<domain>:4443/bash.sh
```

Note that you're required to use HTTPS and access over port 4443, otherwise the WebSocket connection won't work.

Another way to use this script would be to set it up to run on failure.

Ex:

```
cf push -c '<your normal command> || curl -s https://raw.githubusercontent.com/dmikusa-pivotal/cf-debug-tools/master/debug-console.sh | bash'
```

This should run your normal command and if it fails, download and run the debug console.  The advantage here is that you can poke around in the environment after your application has failed, perhaps giving you the chance to see why it failed.

### Additional Notes

It's important to realize that this script is not secure in any way.  It simply opens up the console instead of your application.  Just as you can access this console, so can anyone else with the URL.  As such, be careful when and how you use this.

## SSH Tunnel

This script when run will make an outbound SSH connection to a server of your choice and setup a reverse tunnel so that you can connect from your server to a port in the application's environment.  This can be used to facilitate access to the application environment that would otherwise not be possible.  For example, to connect and run a shell, connect to a hidden port, get metrics and stats or even debug your application.

### Prerequisites & Setup

To use this script, you need a few prerequisites.  First you need an SSH server that is running and accessible from your CloudFoundry installation.  If you're using bosh-lite, this could be as simple as running SSH on your workstation or laptop.  If you're on a public system, you'll need an SSH server that is also publicly accessible.

Second, you'll need a public and private SSH key for your application.  These will be used by the application to connect to your public server without requiring a password to be entered.  It's not possible to enter a password when using this script, so setting up key based access (i.e. `authorized_keys) on your SSH server is a must.

If you don't have one already, you can generate a key pair by running the following two commands from the root of your application directory (or for Java applications in `src/main/webapp`).

```
mkdir .ssh && chmod 700 .ssh
ssh-keygen -f .ssh/<my-key-name> -t rsa -N ‘’
```

This creates a directory called `.ssh` with the correct permissions and places it into the current directory.  It then runs `ssh-keygen` to generate the key pair in the `.ssh` directory without a password.  Again, you must do this without a password because there's no way to enter the password when the script runs.

From here, you just need to add the public key that is generated to the `authorized_keys` file of your OpenSSH server (or something similar for another SSH server).  Before you proceed, test that you can login to your SSH server using your key without a password.

```
ssh -i .ssh/<my-key-name> <user@>host<:port>
```

### Suggested Usage

The easiest way to use this script is with a manifest file.  This allows you to specify the start command to the environment variables that are needed to configure the script.

Ex: Node.js

```
---
applications:
- name: node-1
  memory: 128M
  instances: 1
  host: node-1
  path: .
  command: curl -s https://raw.githubusercontent.com/dmikusa-pivotal/cf-debug-tools/master/ssh-tunnel.sh | bash && node app.js
```

When this application is pushed, it should run like normal, but we prepend the command to execute with `curl -s https://raw.githubusercontent.com/dmikusa-pivotal/cf-debug-tools/master/ssh-tunnel.sh | bash'`.  This downloads the setup script and runs it before your application runs.  Please note, if you're using a build pack that automatically sets the command like the Java build pack, this won't work.  In that case, you'll need to find another way to download and run the script.  While not limited to this, some options are forking the build pack and inserting the command to run or having your application run it at startup.

### Configuration

This script is configured through environment variables that you set on your application.  The following are required to be set.

|      Variable     |   Explanation                                        |
------------------- | -----------------------------------------------------|
| PUBLIC_SERVER     | The connection information for your SSH Server.  It takes the format [user@]server[:port], where user and port are optional.  Ex:  `daniel@my-server:2222` |

The following variables are optional.

|      Variable     |   Explanation                                        |
------------------- | -----------------------------------------------------|
| LOCAL_BASE_PORT   | The first local port to use.  This determines what port you'll connect to on the public server to access the tunneled service.  Because multiple applications can be connecting back to one server the local port used needs to be unique.  This value specifies the first port that the script will start using.  Incremented to this value is the application's instance id.  For example, if you start at 10000 and have three instances, they should be available on 10000, 10001 and 10002.  The default is 31337. Never set this value to anything less than 1024 as the script won't have permissions to bind to that port. |
| SERVICE_PORTS     | This is the port or ports (space separated list) to which the reverse tunnel will connect, or in other words it's the port where the service you'd like to access is listening.  This defaults to $PORT which means you'll be able to access your application over the tunnel.  Generally you'd set this to something different. |

### Additional Notes

It's important to contemplate the security risks of using this script with your application.  You're packaging a non-password protected private key with your application.  If someone else were to get this key, he or she could connect to your SSH server in the same way that this script does.  Because of this it would be a good idea to rotate the keys often, revoke old keys from your `authorized_keys` file and to limit the access of the user on your SSH server (possibly even run it in a VM or container with nothing else).

## License
The cf-debug-tools project is released under version 2.0 of the [Apache License](http://www.apache.org/licenses/LICENSE-2.0).
