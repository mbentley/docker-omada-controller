# mbentley/omada-controller

docker image based off of ubuntu:18.04 for [TP-Link Omada Controller](https://www.tp-link.com/en/products/details/EAP-Controller.html) to control [TP-Link Omada EAP Series Wireless Access Points](https://www.tp-link.com/en/omada/)

## Tags

### Tags for `amd64`

* `latest`, `4.1` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2` - Omada Controller 3.2.x (currently 3.2.10)
* `3.1` - Omada Controller 3.1.x (currently 3.1.13)
* `3.0` - Omada Controller 3.0.x (currently 3.0.5)

### Tags for `armv7l`

* `latest-armv7l`, `4.1-armv7l` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2-armv7l` - Omada Controller 3.2.x (currently 3.2.10)

### Tags for `arm64`

* `latest-arm64`, `4.1-arm64` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2-arm64` - Omada Controller 3.2.x (currently 3.2.10)

## Upgrading to 4.1

<details>
<summary>Click to expand upgrade instructions and 4.1 usage notes</summary>

The upgrade to the 4.1.x version is not a seamless upgrade and can't be done in place.  You must be running at least 3.1.4 or greater before you can proceed.  Instructions are available from [TP-Link](https://www.tp-link.com/en/omada-sdn/controller-upgrade) but many of the steps will be different due to running in a docker container.  Here are the high level steps:

1. Review the steps in the TP-Link instructions as some settings will not transfer to the new version.
1. Take a backup of your controller as described in the [upgrade procedure](https://www.tp-link.com/en/omada-sdn/controller-upgrade/#content-5_1_1)
1. Stop your controller
1. Clear your existing persistent data directories for data, work, and logs.  I would recommend backing up the files so you can revert to the previous version in case of issues.
1. Start your controller with the new Docker image and proceed with at least the basic setup options
1. Import your backup file to the 4.1 version of the controller

## Notes for 4.1

1. **Ports** - Do not change the ports for the controller or portal in the UI to ports below 1024 unless you have adjusted the unprivileged ports; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports).  If you change the default port for the management interface, you should also either disable the container health check or update it to the new port.
1. **SSL Certificates** - if you are installing your own SSL certificates, you should only manage them using one method - through the UI or by using the `/cert` volume as [described below](#custom-certificates).
1. **Synology Users** - if you're using a Synology and are using the `latest` tag and update to 4.1, you will need to make sure to re-create the container due to the `CMD` changing from older versions to 4.1 as Synology retains the entrypoint and command from the container as it is defined and not from the image.

</details>

## Example usage

**Warning**: running with the specific ports being published currently does not work - APs can't be discovered.  Use `host` networking or something like `macvlan` to directly connect the container on it's own IP to the network.  See #45.

To run this Docker image and keep persistent data in named volumes:

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  --net host \
  -e MANAGE_HTTP_PORT=8088 \
  -e MANAGE_HTTPS_PORT=8043 \
  -e PORTAL_HTTP_PORT=8088 \
  -e PORTAL_HTTPS_PORT=8843 \
  -e SHOW_SERVER_LOGS=true \
  -e SHOW_MONGODB_LOGS=false \
  -e SSL_CERT_NAME="tls.crt" \
  -e SSL_KEY_NAME="tls.key" \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:4.1
```

<details>
<summary>Example usage for armv7l</summary>

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  --net host \
  -e MANAGE_HTTP_PORT=8088 \
  -e MANAGE_HTTPS_PORT=8043 \
  -e PORTAL_HTTP_PORT=8088 \
  -e PORTAL_HTTPS_PORT=8843 \
  -e SHOW_SERVER_LOGS=true \
  -e SHOW_MONGODB_LOGS=false \
  -e SSL_CERT_NAME="tls.crt" \
  -e SSL_KEY_NAME="tls.key" \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:4.1-armv7l
```
</details>

<details>
<summary>Example usage for arm64</summary>

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  --net host \
  -e MANAGE_HTTP_PORT=8088 \
  -e MANAGE_HTTPS_PORT=8043 \
  -e PORTAL_HTTP_PORT=8088 \
  -e PORTAL_HTTPS_PORT=8843 \
  -e SHOW_SERVER_LOGS=true \
  -e SHOW_MONGODB_LOGS=false \
  -e SSL_CERT_NAME="tls.crt" \
  -e SSL_KEY_NAME="tls.key" \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:4.1-arm64
```
</details>


## Optional Variables

| Variable | Default | Values | Description |
| :------- | :------ | :----: | :---------- |
| `MANAGE_HTTP_PORT` | `8088` | `1024`-`65535` | Management portal HTTP port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) |
| `MANAGE_HTTPS_PORT` | `8043` | `1024`-`65535` | Management portal HTTPS port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) |
| `PORTAL_HTTP_PORT` | `8088` | `1024`-`65535` | User portal HTTP port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) |
| `PORTAL_HTTPS_PORT` | `8843` | `1024`-`65535` | User portal HTTPS port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) |
| `SHOW_SERVER_LOGS` | `true` | `[true\|false]` | Outputs Omada Controller logs to STDOUT at runtime |
| `SHOW_MONGODB_LOGS` | `false` | `[true\|false]` | Outputs MongoDB logs to STDOUT at runtime |
| `SMALL_FILES` | `false` | `[true\|false]` | See [Small Files](#small-files) for more detail; deprecated in 4.1.x |
| `SSL_CERT_NAME` | `tls.crt` | _any_ | Name of the public cert chain mounted to `/cert`; see [Custom Certificates](#custom-certificates) |
| `SSL_KEY_NAME` | `tls.key` | _any_ | Name of the private cert mounted to `/cert`; see [Custom Certificates](#custom-certificates) |
| `TZ` | `Etc/UTC` | _\<many\>_ | See [Time Zones](#time-zones) for more detail |


## Persistent Data and Permissions

**Note**: This only applies to tags for `3.1.x` and `3.0.x` as the `3.2.x` and newer versions manage the permissions for you.

If you utilize bind mounts instead of Docker named volumes (e.g. - `-v /path/to/data:/opt/tplink/EAPController/data`) in your run command, you will want to make sure that you have set the permissions appropriately on the filesystem otherwise you will run into permissions errors and the container will not run because it won't have the permissions to write data since this container uses a non-root user.  To resolve that, you need to `chown` the directory to `508:508` on the host as that is the UID and GID that we use inside the container.  For example:

```
chown -R 508:508 /data/omada/data /data/omada/work /data/omada/logs
```

## Custom Certificates

By default, Omada software uses self-signed certificates. If however you want to use custom certificates you can mount them into the container as `/cert/tls.key` and `/cert/tls.crt`. The `tls.crt` file needs to include the full chain of certificates, i.e. cert, intermediate cert(s) and CA cert. This is compatible with kubernetes TLS secrets. Entrypoint script will convert them into Java Keystore used by jetty inside the Omada SW.  If you need to use different file names, you can customize them by passing values for `SSL_CERT_NAME` and `SSL_KEY_NAME` as seen above in the [Optional Variables](#optional-variables) section.

**Warning** - As of the version 4.1, certificates can also be installed through the web UI.  You should not attempt to mix certificate management methods as installing certificates via the UI will store the certificates in MongoDB and then the `/cert` volume method will cease to function.

## Small Files

In Omada 3.2 and older, this image uses the default mongodb settings for journal files.  If disk space is an issue, you can set the `SMALL_FILES` variable to `true` which will add [`--smallfiles`](https://docs.mongodb.com/v3.6/core/journaling/#journaling-journal-files) to the startup arguments for MongoDB.

**Warning** - As of the version 4.1 and newer, MongoDB utilizes the `WiredTiger` storage engine by default which does not have the same journal file size issue as the `MMAPv1` storage engine.  If `SMALL_FILES` is set to `true`, a warning will be issued at startup but startup will still proceed.

## Time Zones

By default, this image uses the `Etc/UTC` time zone.  You may update the time zone used by passing a different value in the `TZ` variable.  See [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) for a complete list of values in the `TZ database name` table column.

## Unprivileged Ports

This Docker image runs as a non-root user by default.  In order to bind unprivileged ports (ports < 1024 by default), you must include `--sysctl net.ipv4.ip_unprivileged_port_start=0` in your `docker run` command to allow ports below 1024 to be bound by non-root users.
