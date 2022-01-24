# mbentley/omada-controller

docker image based off of ubuntu:18.04 for [TP-Link Omada Controller](https://www.tp-link.com/us/business-networking/omada-sdn-controller/) to control [TP-Link Omada Hardware](https://www.tp-link.com/en/business-networking/all-omada/)

## Table of Contents

* [Image Tags](#image-tags)
  * [Multi-arch Tags](#multi-arch-tags)
  * [Explicit Architecture Tags](#explicit-architecture-tags)
  * [Archived Tags](#archived-tags)
* [Reporting Issues](#reporting-issues)
* [Upgrading to 5.0.x from 4.1.x or above](#upgrading-to-50x-from-41x-or-above)
  * [Changes/Notes for 5.0.x](#changesnotes-for-50x)
* [Upgrading to 4.1 from 3.2.10 or below](#upgrading-to-41-from-3210-or-below)
  * [Notes for 4.1](#notes-for-41)
* [Building Images](#building-images)
* [Example Usage](#example-usage)
  * [Using non-default ports](#using-non-default-ports)
  * [Using port mapping](#using-port-mapping)
  * [Using `net=host`](#using-nethost)
* [Optional Variables](#optional-variables)
* [Persistent Data and Permissions](#persistent-data-and-permissions)
* [Custom Certificates](#custom-certificates)
* [MongoDB Small Files](#mongodb-small-files)
* [Time Zones](#time-zones)
* [Unprivileged Ports](#unprivileged-ports)
* [Using Docker Compose](#using-docker-compose)
* [Known Issues](#known-issues)
  * [Upgrade Issues](#upgrade-issues)

## Image Tags

### Multi-arch Tags

The following tags have multi-arch support for `amd64`, `armv7l`, and `arm64` and will automatically pull the correct tag based on your system's architecture:

`latest`, `5.0`, `4.4`, `4.3`, `4.2`, `4.1`, `3.2`

### Explicit Architecture Tags

These tags will explicitly pull the image for the listed architecture and are bit for bit identical to the multi-arch tags images.

#### [`amd64`](https://hub.docker.com/repository/docker/mbentley/omada-controller/tags?page=1&ordering=last_updated&name=amd64)

* `latest`, `5.0` - Omada Controller 5.0.x (currently 5.0.30)
* `4.4` - Omada Controller 4.4.x (currently 4.4.8)
* `4.3` - Omada Controller 4.3.x (currently 4.3.5)
* `4.2` - Omada Controller 4.2.x (currently 4.2.11)
* `4.1` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2` - Omada Controller 3.2.x (currently 3.2.14)

#### [`armv7l`](https://hub.docker.com/repository/docker/mbentley/omada-controller/tags?page=1&ordering=last_updated&name=armv7l)

* `latest-armv7l`, `5.0-armv7l` - Omada Controller 5.0.x (currently 5.0.30)
* `4.4-armv7l` - Omada Controller 4.4.x (currently 4.4.8)
* `4.3-armv7l` - Omada Controller 4.3.x (currently 4.3.5)
* `4.2-armv7l` - Omada Controller 4.2.x (currently 4.2.11)
* `4.1-armv7l` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2-armv7l` - Omada Controller 3.2.x (currently 3.2.14)

#### [`arm64`](https://hub.docker.com/repository/docker/mbentley/omada-controller/tags?page=1&ordering=last_updated&name=arm64)

* `latest-arm64`, `5.0-arm64` - Omada Controller 5.0.x (currently 5.0.30)
* `4.4-arm64` - Omada Controller 4.4.x (currently 4.4.8)
* `4.3-arm64` - Omada Controller 4.3.x (currently 4.3.5)
* `4.2-arm64` - Omada Controller 4.2.x (currently 4.2.11)
* `4.1-arm64` - Omada Controller 4.1.x (currently 4.1.5)
* `3.2-arm64` - Omada Controller 3.2.x (currently 3.2.14)

## Archived Tags

These images are still published on Docker Hub but are no longer regularly updated due to the controller software no longer being updated.  **Use with extreme caution as these images are likely to contain unpatched security vulnerabilities!**

* `3.1` - Omada Controller 3.1.x (currently 3.1.13)
* `3.0` - Omada Controller 3.0.x (currently 3.0.5)

## Reporting Issues

If you have issues running the controller, feel free to [file an issue](https://github.com/mbentley/docker-omada-controller/issues/new) and I will help as I can.  If you are specifically having a problem that is related to the actual software, I would suggest filing an issue on the [TP-Link community forums](https://community.tp-link.com/en/business/forum/582) as I do not have access to source code to debug those issues.  If you're not sure where the problem might be, I can help determine if it is a running in Docker issue or a software issue.

## Upgrading to 5.0.x from 4.1.x or above

There are no manual upgrade steps directly related to the software itself required when upgrading to 5.0.x if you are already running at least 4.1.x.  For full details, please refer to the [TP-Link upgrade documentation](https://www.tp-link.com/en/omada-sdn/controller-upgrade/).

As always, I would recommend taking a backup through the controller software as well as save a copy of the persistent data while the controller is not running when you do upgrade to simplify the rollback process, if required.

### Changes/Notes for 5.0.x

* **Updated Ports** - If you are only exposing ports using port mapping as the list of ports required has been updated.  Starting with 5.0.x, the controller is also listening on `TCP port 29814` so you should add `-p 29814:29814` to your run command, compose file, or however you're running the container.  Some additional unnecessary ports are no longer required so the list is shorter now.
* **Custom Ports** - If using custom ports from the defaults of 8088, 8043, and 8843, they will _not_ persist across container re-creation starting in 5.0 unless you **always** set the `MANAGE_*_PORT` enviornment variables.  This is due to adding `/opt/tplink/EAPController/properties` to the classpath starting in 5.0.  If you change the ports through the UI, you should still continue to also set the ports using the environment variables, matching the ports you have set in the UI.  For more detail, see [Using non-default ports](#using-non-default-ports).

## Upgrading to 4.1 from 3.2.10 or below

The upgrade to the 4.1.x version is not a seamless upgrade and can't be done in place.  You must be running at least 3.1.4 or greater before you can proceed.  Instructions are available from [TP-Link](https://www.tp-link.com/en/omada-sdn/controller-upgrade/) but many of the steps will be different due to running in a docker container.  Here are the high level steps:

1. Review the steps in the TP-Link instructions as some settings will not transfer to the new version.
1. Take a backup of your controller as described in the [upgrade procedure](https://www.tp-link.com/en/omada-sdn/controller-upgrade/#content-5_1_1)
1. Stop your controller
1. Clear your existing persistent data directories for data, work, and logs.  I would recommend backing up the files so you can revert to the previous version in case of issues.
1. Start your controller with the new Docker image and proceed with at least the basic setup options
1. Import your backup file to the 4.1 version of the controller

### Notes for 4.1

1. **Ports** - Do not change the ports for the controller or portal in the UI to ports below 1024 unless you have adjusted the unprivileged ports; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports).
1. **SSL Certificates** - if you are installing your own SSL certificates, you should only manage them using one method - through the UI or by using the `/cert` volume as [described below](#custom-certificates).
1. **Synology Users** - if you're using a Synology and are using the `latest` tag and update to 4.1, you will need to make sure to re-create the container due to the `CMD` changing from older versions to 4.1 as Synology retains the entrypoint and command from the container as it is defined and not from the image.

## Building images

<details>
<summary>Click to expand docker build instructions</summary>

As of the Omada Controller version 4.2.x, the Dockerfiles have been simplified so that there is a unified Dockerfile.  There are some differences between the build steps for `amd64`, `arm64`, and `armv7l`.  These changes will happen automatically if you use the following build-args:

### `amd64`

  No build args required; set for the default build-args

  ```
  docker build -f Dockerfile.v5.0.x -t mbentley/omada-controller:5.0 .
  ```

### `arm64`

  Only the `ARCH` build-arg is required

  ```
  docker build --build-arg ARCH="arm64" -f Dockerfile.v5.0.x -t mbentley/omada-controller:5.0-arm64 .
  ```

### `armv7l`

  Both the `ARCH` and `BASE` build-args are required

  ```
  docker build --build-arg ARCH="armv7l" --build-arg BASE="ubuntu:16.04" -f Dockerfile.v5.0.x -t mbentley/omada-controller:5.0-armv7l .
  ```

</details>

## Example Usage

To run this Docker image and keep persistent data in named volumes:

### Using non-default ports

__tl;dr__: Always make sure the environment variables for the ports match any changes you have made in the web UI and you'll be fine.

If you want to change the ports of your Omada Controller to something besides the defaults, there is some unexpected behavior that the controller exhibits.  There are two sets of ports: one for HTTP/HTTPS for the controller itself and another for HTTP/HTTPS for the captive portal, typically used for authentication to a guest network.  The controller's set of ports, which are set by the `MANAGE_*_PORT` environment variables, can only be modified using the environment variables on the first time the controller is started.  If persistent data exists, changing the controller's ports via environment variables will have no effect on the controller itself and can only be modified through the web UI.  On the other hand, the portal ports will always be set to whatever has been set in the environment variables, which are set by the `PORTAL_*_PORT` environment variables.

### Using port mapping

__Warning__: If you want to change the controller ports from the default mappings, you *absolutely must* update the port binding inside the container via the environment variables.  The ports exposed must match what is inside the container.  The Omada Controller software expects that the ports are the same inside the container and outside and will load a blank page if that is not done.  See [#99](https://github.com/mbentley/docker-omada-controller/issues/99#issuecomment-821243857) for details and and example of the behavior.

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810/udp \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
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
  mbentley/omada-controller:5.0
```

### Using `net=host`

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
  mbentley/omada-controller:5.0
```

<details>
<summary>Example usage for armv7l</summary>

### Using port mapping

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810/udp \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
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
  mbentley/omada-controller:5.0-armv7l
```

### Using `net=host`

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
  mbentley/omada-controller:5.0-armv7l
```

</details>

<details>
<summary>Example usage for arm64</summary>

### Using port mapping

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810/udp \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
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
  mbentley/omada-controller:5.0-arm64
```

### Using `net=host`

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
  mbentley/omada-controller:5.0-arm64
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
| `TLS_1_11_ENABLED` | `false` | `[true\|false]` | Re-enables TLS 1.0 & 1.1 if set to `true` for 4.1.x and above |
| `TZ` | `Etc/UTC` | _\<many\>_ | See [Time Zones](#time-zones) for more detail |

## Persistent Data and Permissions

**Note**: The permissions portion only applies to tags for `3.1.x` and `3.0.x` as the `3.2.x` and newer versions manage the permissions for you.

If you utilize bind mounts instead of Docker named volumes (e.g. - `-v /path/to/data:/opt/tplink/EAPController/data`) in your run command, you will want to make sure that you have set the permissions appropriately on the filesystem otherwise you will run into permissions errors and the container will not run because it won't have the permissions to write data since this container uses a non-root user.  To resolve that, you need to `chown` the directory to `508:508` on the host as that is the UID and GID that we use inside the container.  For example:

```
chown -R 508:508 /data/omada/data /data/omada/work /data/omada/logs
```

In the examples, there are three directories where persistent data is stored: `data`, `work`, and `logs`.  The `data` directory is where the persistent database data is stored where all of your settings, app configuration, etc is stored.  The `work` directory is where the web application is extracted to and is just ephemeral data that is replaced on each run.  The `log` directory is where logs are written and stored.  I would suggest that you use a bind mounted volume for the `data` directory to ensure that your persistent data is directly under your control and of course take regular backups within the Omada Controller application itself.

## Custom Certificates

By default, Omada software uses self-signed certificates. If however you want to use custom certificates you can mount them into the container as `/cert/tls.key` and `/cert/tls.crt`. The `tls.crt` file needs to include the full chain of certificates, i.e. cert, intermediate cert(s) and CA cert. This is compatible with kubernetes TLS secrets. Entrypoint script will convert them into Java Keystore used by jetty inside the Omada SW.  If you need to use different file names, you can customize them by passing values for `SSL_CERT_NAME` and `SSL_KEY_NAME` as seen above in the [Optional Variables](#optional-variables) section.

**Warning** - As of the version 4.1, certificates can also be installed through the web UI.  You should not attempt to mix certificate management methods as installing certificates via the UI will store the certificates in MongoDB and then the `/cert` volume method will cease to function.

## MongoDB Small Files

In Omada 3.2 and older, this image uses the default mongodb settings for journal files.  If disk space is an issue, you can set the `SMALL_FILES` variable to `true` which will add [`--smallfiles`](https://docs.mongodb.com/v3.6/core/journaling/#journaling-journal-files) to the startup arguments for MongoDB.

**Warning** - As of the version 4.1 and newer, MongoDB utilizes the `WiredTiger` storage engine by default which does not have the same journal file size issue as the `MMAPv1` storage engine.  If `SMALL_FILES` is set to `true`, a warning will be issued at startup but startup will still proceed.

## Time Zones

By default, this image uses the `Etc/UTC` time zone.  You may update the time zone used by passing a different value in the `TZ` variable.  See [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) for a complete list of values in the `TZ database name` table column.

## Unprivileged Ports

This Docker image runs as a non-root user by default.  In order to bind unprivileged ports (ports < 1024 by default), you must include `--sysctl net.ipv4.ip_unprivileged_port_start=0` in your `docker run` command to allow ports below 1024 to be bound by non-root users.

## Using Docker Compose

There is a [Docker Compose file](https://github.com/mbentley/docker-omada-controller/blob/master/docker-compose.yml) available for those who would like to use compose to manage the lifecycle of their container:

```
wget https://raw.githubusercontent.com/mbentley/docker-omada-controller/master/docker-compose.yml
docker-compose up -d
```

## Known Issues

### Upgrade Issues

It has been reported that users of some NAS devices such as a Synology or users of a Docker management UI like Portainer have had issues with upgrades due to the CMD being retained between versions.  This normally does not happen with the Docker command line so it is a bit of an unexpected pattern but it can not be overwritten as it exists outside of the container.

If updating from 3.x to 4.x or 4.x to 5.x, make sure to **completely** re-create the container otherwise the controller will not start. This is due to the CMD changing between the major releases as some web interfaces like Synology or Portainer retain the entrypoint and command explicitly instead of inheriting it from the image. To resolve the issue, do one of the following:

* Re-create the container - remove the container, keeping your persistent data and create it again using whatever method you used to originally create it.
* Update the CMD (command is all on one line):
  * 4.x to 5.x - `/usr/bin/java -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof -Djava.awt.headless=true -cp /opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties: com.tplink.smb.omada.starter.OmadaLinuxMain`

It should be noted that users of 3.x who wish to upgrade to 4.x must perform [specific upgrade steps](#upgrading-to-41-from-3210-or-below) to prevent data loss!
