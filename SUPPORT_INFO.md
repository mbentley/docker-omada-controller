# Support Information to Gather When Asking for Help

When filing either an issue or discussion for help, it is always helpful to provide as much information as possible.  Here are the things that will be helpful for troubleshooting purposes:

1. The version of the controller you're running.
    * This can be found in the container's logs so at least if you provide the logs, I can find it in there if you really do not know.
1. How You're Launching the Container
    * This is either going to be a `docker run` command, compose file, or the equivalent of whatever tool you're launching the container from.
    * If you do not have any of this information, for whatever reason, you can provide the output of `docker container inspect omada-controller` to provide enough information to help.
1. Details of the docker image you're running from the output of:
    * `docker inspect omada-controller --format '{{json .Image}}'`
    * `docker images --filter=reference='mbentley/omada-controller' --digests --format '{{.Repository}}:{{.Tag}}@{{.Digest}}'`
1. Container & App Logs
    * Container logs can be collected using `docker logs omada-controller >& output.log` to put them in a file called `output.log`.
    * MongoDB logs do not log to the console by default as they can be very verbose but they can be collected using `docker cp omada-controller:/opt/tplink/EAPController/logs/mongod.log .` to copy out the `mongod.log` to the current directory.  The `mongod.log` file may also be in a volume if you have specified a volume path for the container's `/opt/tplink/EAPController/logs` directory.  These logs are especially helpful when the container is not starting as expected.
