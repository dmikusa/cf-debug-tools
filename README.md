# Debug Tools for CloudFoundry

This project is a collection of scripts that can be used to help troubleshoot applications deployed to CloudFoundry.  See each script for more details.

## Cloud Controller & GoRouter Access Log Stats

The `toplogs-gorouter.sh` and `toplogs-cloudcontroller.sh` scripts can be used to read the access log from GoRouter or Cloud Controller Nginx and generate some helpful and commonly used metrics.  

Included for GoRouter are top 10 lists of:

   - response codes
   - request methods
   - request paths
   - request paths w/query params
   - user agent
   - Referrer
   - Remote Address
   - Backend Address
   - Client IP
   - Destination Host
   - Application UUID
   - Request counts by day, hour, minute, second
   - Response times rounded to the second

Include for Cloud Controller are top 10 lists of:

  - response codes
  - request methods
  - request paths
  - request paths w/query params
  - user agents
  - referrers
  - forwarded IPs
  - direct client IP
  - Request counts by day, hour, minute, second
  - response times rounded to the second

### Usage

```
USAGE:
toplogs-gorouter.sh [-t|--top 10] <file1> <file2> <file3> ...

    -t|--top - defaults to 10, sets the number of results to return

NOTES:
  Assumes standard GoRouter access log format:
    <Request Host> - [<Start Date>] "<Request Method> <Request URL> <Request Protocol>" <Status Code> <Bytes Received> <Bytes Sent> "<Referer>" "<User-Agent>" <Remote Address> <Backend Address> x_forwarded_for:"<X-Forwarded-For>" x_forwarded_proto:"<X-Forwarded-Proto>" vcap_request_id:<X-Vcap-Request-ID> response_time:<Response Time> app_id:<Application ID> app_index:<Application Index> x_b3_traceid:<zipkin-trace> x_b3_spandid:<zipkin-span> x_b3_parentspanid:<zipkin-spanid>

  It's also worth noting that this format is fluid.  Everything after `app_index` is "additional headers" that may or may not be present.  It defaults to what should work for PCF, but may need to be adjusted for other situations.
```

```
USAGE:
toplogs-cloudcontroller.sh [-t|--top 10] <file1> <file2> <file3> ...

    -t|--top - defaults to 10, sets the number of results to return

NOTES:
  Assumes standard CloudController Nginx access log format:
    <client ip> - [<date>:<time>] "<method> <request path> <http version>" <status code> <bytes> "<referrer" "<user agent>" <x-forwarded-for> vcap_request_id:<reqest_id> response_time:<response_time>
```

## Use profile.d to dump the JVM Native Memory

By using [start_dump.sh](start_dump.sh) and [dump.sh](dump.sh) along with [.profile.d](https://devcenter.heroku.com/articles/profiled#order), developers can do a regular native memory dump on JVM and print it on console.

### Todo

* Enable native memory tracking by setting JAVA_OPTS with -XX:NativeMemoryTracking=summary
* Create a folder named with **.profile.d** in the home directory of the application
* Put start_dump.sh inside of **.profile.d**
* Put dump.sh in the home directory of the application
* cf push from home directory of the application

Sample File structure:

```
  .profile.d
    - start_dump.sh
  WEB-INF
    - .....
  dump.sh  
```

manifest:

```
---
applications:
- name: memory_test
  memory: 800m
  instances: 1
  path: .
  env:
    JAVA_OPTS: -Djava.security.egd=file:///dev/urandom -XX:NativeMemoryTracking=summary -XX:+PrintHeapAtGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps
```

Note: If **dump.sh** is setup to look for a WAR file deployed to Tomcat.  If you're using Spring Boot, you need to adjust [this line](https://github.com/dmikusa-pivotal/cf-debug-tools/blob/master/dump.sh#L11) so that it finds your process.  Try grep'ing for `org.springframework.boot.loader.JarLoader` instead.

### Logs

When you run the dump.sh script and grab the Java NMT logs, there's a lot of output that get's generated.  The easiest way to handle this is to run `cf logs app-name > app-name.log` in a terminal before you start the app.  This will capture a complete set of logs from app startup until you see a problem.

With that log file, you can use the build-graph.py script also included make sense of the logs.  The script will parse through and process the Java NMT stats, the output from top and any crashes it detects.  It will then generate graphs to show the memory usage as reported by those tools over time.

To run the script, simply run `python build-graph.py <log-file-name> <pid>` (you can find the pid in your log file, look at the top output).  Please note that the script requires matplotlib and python-dateutils.  These can be installed by running `pip install matplotlib python-dateutils`.

### Other Ways to get Java NMT Metrics

Here's a couple other options for getting Java NMT metrics [[1](https://github.com/mcabaj/nmt-metrics)][[2](https://github.com/jtuchscherer/spring-music/tree/master/src/main/java/org/cloudfoundry/samples/music/nmt)].  These two examples implement the logic of my scripts above in Java and shell out to call `jcmd`.  The nice thing about this is that metrics can then be reported through Spring Boot actuator, assuming you're using Spring, or some other convenient way for your app to report metrics.

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
