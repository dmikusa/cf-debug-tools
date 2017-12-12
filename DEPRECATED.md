# Deprecated Tools

These are tools that used to be necessary but have been replaced by other, better tools and methods.

## Debug Console

This script downloads and installs [websocketd](https://github.com/joewalnes/websocketd).  It simply automates the steps described [here](http://www.iamjambay.com/2013/12/send-interactive-commands-to-cloud.html).

### Replaced By

This has been replaced by `cf ssh`.  You might still consider using this if `cf ssh` is disabled in your environment.

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

### Other Options

If you're looking for a shell running on CF, you could also look at [this example](https://github.com/dmikusa-pivotal/cf-ex-gotty).  It shows how to run [gotty](https://github.com/yudai/gotty) on CF.

