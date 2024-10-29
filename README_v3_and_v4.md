# README for v3 and v4

This README is the consolidation of information from the v3 and v4 images which has been removed from the main README.

## Table of Contents

* [Image Tags](#image-tags)
* [Archived Tags](#archived-tags)
* [Upgrade Path](#upgrade-path)
* [Upgrading to 5.0.x from 4.1.x or above](#upgrading-to-50x-from-41x-or-above)
    * [Changes/Notes for 5.0.x](#changesnotes-for-50x)
* [Upgrading to 4.1 from 3.2.10 or below](#upgrading-to-41-from-3210-or-below)
    * [Notes for 4.1](#notes-for-41)
* [Example Usage](#example-usage)
    * [4.x - Example Usage](#4x---example-usage)
    * [4.x - Using Port Mapping](#4x---using-port-mapping)
    * [4.x - Using net=host](#4x---using-nethost)
    * [3.x - Example Usage](#3x---example-usage)
    * [3.x - Using Port Mapping](#3x---using-port-mapping)
    * [3.x - Using net=host](#3x---using-nethost)
* [Persistent Data and Permissions](#persistent-data-and-permissions)
* [MongoDB Small Files](#mongodb-small-files)

## Image Tags

:warning: **Warning** :warning: Do **NOT** run the `armv7l` (32 bit) images. Upgrade your operating system to `arm64` (64 bit) unless you accept that you're running an outdated MongoDB and a base operating system with unpatched vulnerabilities! See the [Known Issues readme](KNOWN_ISSUES.md#notes-for-armv7l) for more information.

## Archived Tags

All of the v3 and v4 images are still published on Docker Hub but are no longer regularly updated due to the controller software no longer being updated. **Use with extreme caution as these images are likely to contain unpatched security vulnerabilities!**

The following tags have multi-arch support for `amd64`, `armv7l`, and `arm64` and will automatically pull the correct tag based on your system's architecture:

| Tag(s) | Major.Minor Release | Current Version |
| :----- | ------------------- | ----------------|
| `4.4` | Omada Controller `4.4.x` | `4.4.8` |
| `4.3` | Omada Controller `4.3.x` | `4.3.5` |
| `4.2` | Omada Controller `4.2.x` | `4.2.11` |
| `4.1` | Omada Controller `4.1.x` | `4.1.5` |
| `3.2` | Omada Controller `3.2.x` | `3.2.17` |
| `3.1` | Omada Controller `3.1.x` | `3.1.13` |
| `3.0` | Omada Controller `3.0.x` | `3.0.5` |

## Upgrade Path

As always, take backups and read the documentation but the quick explanation of the upgrade path is:

* `3.2` -> `4.1`
    * This is a manual upgrade. See [Upgrading to 4.1 from 3.2.10 or below](#upgrading-to-41-from-3210-or-below).
* `4.1` or `4.4` -> `5.13` -> `5.x` (latest)
    * These are automatic upgrades that take place by updating the image tag.
    * **Note**: Upgrading to `5.13.x` as an intermediate step is required due to `5.14.32.2` removing support for upgrading from v4 to v5.

## Upgrading to 5.0.x from 4.1.x or above

There are no manual upgrade steps directly related to the software itself required when upgrading to 5.0.x if you are already running at least 4.1.x. For full details, please refer to the [TP-Link upgrade documentation](https://www.tp-link.com/en/omada-sdn/controller-upgrade/).

As always, I would recommend taking a backup through the controller software as well as save a copy of the persistent data while the controller is not running when you do upgrade to simplify the rollback process, if required.

### Changes/Notes for 5.0.x

* **Updated Ports** - If you are only exposing ports using port mapping as the list of ports required has been updated. Starting with 5.0.x, the controller is also listening on `TCP port 29814` so you should add `-p 29814:29814` to your run command, compose file, or however you're running the container. Some additional unnecessary ports are no longer required so the list is shorter now.
* **Volume Updates** - Starting with 5.0.x, the controller software is now built using Spring Boot. This version no longer uses the `work` volume as the application is no longer extracted to a temporary directory. If you do nothing, there will be no impact except for an extra directory sitting around.
* **Custom Ports** - If using custom ports from the defaults of 8088, 8043, and 8843, they will _not_ persist across container re-creation starting in 5.0 unless you **always** set the `MANAGE_*_PORT` enviornment variables. This is due to adding `/opt/tplink/EAPController/properties` to the classpath starting in 5.0. If you change the ports through the UI, you should still continue to also set the ports using the environment variables, matching the ports you have set in the UI. For more detail, see [Using non-default ports](#using-non-default-ports).

## Upgrading to 4.1 from 3.2.10 or below

The upgrade to the 4.1.x version is not a seamless upgrade and can't be done in place. You must be running at least 3.1.4 or greater before you can proceed. Instructions are available from [TP-Link](https://www.tp-link.com/en/omada-sdn/controller-upgrade/) but many of the steps will be different due to running in a docker container. Here are the high level steps:

1. Review the steps in the TP-Link instructions as some settings will not transfer to the new version.
1. Take a backup of your controller as described in the [upgrade procedure](https://www.tp-link.com/en/omada-sdn/controller-upgrade/#content-5_1_1)
1. Stop your controller
1. Clear your existing persistent data directories for data, work, and logs. I would recommend backing up the files so you can revert to the previous version in case of issues.
1. Start your controller with the new Docker image and proceed with at least the basic setup options
1. Import your backup file to the 4.1 version of the controller

### Notes for 4.1

1. **Ports** - Do not change the ports for the controller or portal in the UI to ports below 1024 unless you have adjusted the unprivileged ports; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports).
1. **SSL Certificates** - if you are installing your own SSL certificates, you should only manage them using one method - through the UI or by using the `/cert` volume as [described below](#custom-certificates).
1. **Synology Users** - if you're using a Synology and are using the `latest` tag and update to 4.1, you will need to make sure to re-create the container due to the `CMD` changing from older versions to 4.1 as Synology retains the entrypoint and command from the container as it is defined and not from the image.

## Example Usage

For additional usage information, check out [this revision](https://github.com/mbentley/docker-omada-controller/blob/9885438b013651d18c29b5b2b9e1d18be70e2e5c/README.md) in the git history.

### Using non-default ports

__tl;dr__: Always make sure the environment variables for the ports match any changes you have made in the web UI and you'll be fine.

**Note**: The `3.2` version of the controller only supports the `MANAGE_HTTP_PORT` and `MANAGE_HTTPS_PORT` variables for modifying the controller's admin web interface ports. This means that setting `PORTAL_HTTP_PORT` and `PORTAL_HTTPS_PORT` will not have any effect in `3.2`. Versions `4.x` or greater support all of the `MANAGE_*_PORT` and `PORTAL_*_PORT` variables as described in the [Optional Variables](#optional-variables) section.

### 4.x - Example Usage

#### 4.x - Using port mapping

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810 \
  -p 29810:29810/udp \
  -p 29811:29811 \
  -p 29811:29811/udp \
  -p 29812:29812 \
  -p 29812:29812/udp \
  -p 29813:29813 \
  -p 29813:29813/udp \
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
  mbentley/omada-controller:4.4
```

#### 4.x - Using `net=host`

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
  mbentley/omada-controller:4.4
```

### 3.x - Example Usage

#### 3.x - Using port mapping

The below example can be used with 3.2. The port and volume mappings have changed in newer versions.

```
docker run -d \
  --name omada-controller \
  --stop-timeout 60 \
  --restart unless-stopped \
  --ulimit nofile=4096:8192 \
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
  -e SMALL_FILES=false \
  -e SSL_CERT_NAME="tls.crt" \
  -e SSL_KEY_NAME="tls.key" \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:3.2
```

#### 3.x - Using `net=host`

```
docker run -d \
  --name omada-controller \
  --stop-timeout 60 \
  --restart unless-stopped \
  --ulimit nofile=4096:8192 \
  --net host \
  -e MANAGE_HTTP_PORT=8088 \
  -e MANAGE_HTTPS_PORT=8043 \
  -e SMALL_FILES=false \
  -e SSL_CERT_NAME="tls.crt" \
  -e SSL_KEY_NAME="tls.key" \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:3.2
```

## Persistent Data and Permissions

**Note**: The permissions portion only applies to tags for `3.1.x` and `3.0.x` as the `3.2.x` and newer versions manage the permissions for you.

If you utilize bind mounts instead of Docker named volumes (e.g. - `-v /path/to/data:/opt/tplink/EAPController/data`) in your run command, you will want to make sure that you have set the permissions appropriately on the filesystem otherwise you will run into permissions errors and the container will not run because it won't have the permissions to write data since this container uses a non-root user. To resolve that, you need to `chown` the directory to `508:508` on the host as that is the UID and GID that we use inside the container. For example:

```bash
chown -R 508:508 /data/omada/data /data/omada/logs
```

In the examples, there are two directories where persistent data is stored: `data` and `logs`. The `data` directory is where the persistent database data is stored where all of your settings, app configuration, etc is stored. The `log` directory is where logs are written and stored. I would suggest that you use a bind mounted volume for the `data` directory to ensure that your persistent data is directly under your control and of course take regular backups within the Omada Controller application itself.

## MongoDB Small Files

In Omada 3.2 and older, this image uses the default mongodb settings for journal files. If disk space is an issue, you can set the `SMALL_FILES` variable to `true` which will add [`--smallfiles`](https://docs.mongodb.com/v3.6/core/journaling/#journaling-journal-files) to the startup arguments for MongoDB.

**Warning** - As of the version 4.1 and newer, MongoDB utilizes the `WiredTiger` storage engine by default which does not have the same journal file size issue as the `MMAPv1` storage engine. If `SMALL_FILES` is set to `true`, a warning will be issued at startup but startup will still proceed.
