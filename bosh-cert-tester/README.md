## Bosh Deployed Certificate Tester

Bosh has the capability to deploy trusted SSL/TLS certs to all bosh deployed VMs.  Furthermore, Cloud Foundry will then take the bosh deployed trusted certs and import them into application containers.  Often this works just fine, but in some cases there are problems.

For example:
 - maybe certs don't get deployed to the VM
 - maybe certs don't get deployed to the app container
 - maybe the certs are invalid for some reason
 - maybe there's user error and an expected cert was not included in the list

This folder contains an application that can be deployed to CF that returns information about the Bosh deployed certs.  It can also be used to test connectivity to endpoints that should be trusted by sending HTTPS or TCP/TLS requests.  These requests will indicate if the remote endpoint is trusted based on the trusted certs in the container.

## Usage

To use:

```
$ git clone https://github.com/dmikusa-pivotal/cf-debug-tools
$ cd bosh-cert-tester/
```

Edit the `https-endpoints.json` and `tcp-endpoints.json` files to include a list of HTTPS and TCP endpoints that the app should connect to.  These would be the resources to which your applications will connect and that depend on the Bosh deployed trusted certs.

For example, if you have a web service at `https://my-service.com/` and it presents a TLS cert that is signed by your internal CA then you could include that URL to confirm that the internal CA has been bosh deployed to the VM and included in the app container.  You'll know the trusted cert is included if the connection is successful.  If it fails with a cert error, then it's not include or there is some other problem with the certs.

Once you've edited these lists run `cf push` to deploy the application.

To retrieve the output from the script you can either run `cf logs bosh-cert-tester` in a separate terminal or you can run `scp -P 2222 -oUser=cf:$(cf app bosh-cert-tester --guid)/0 "$(cf curl /v2/info | jq -r .app_ssh_endpoint | cut -d ':' -f 1)":./app/output.txt ./` to download the text file from the app container (run `cf ssh-code` and enter the token when prompted by `scp` for a password).

## Output

Included in the output are the following items:

 - a list of the bosh deployed certs and a detailed print out of each cert
 - a list of all the certs in the CA cert bundle
 - output from `curl` for each service listed in `https-endpoints.json`
 - output from `openssl s_client` for each service listed in `tcp-endpoints.json`

