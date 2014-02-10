cf-debug-console
================

This project is a simple script that downloads and installs websocketd.  It's meant to be used with the CloudFoundry system as a way to interactively debug an application that's not working properly.

Suggested Usage
===============

There's two ways that this can be used.  First by using the ```--command``` argument to cf.  The second is integrated with a build pack.  Build pack authors can put this in their start script at the end.  That way if the start script fails, this command will run and setup a debug console for the environment.
