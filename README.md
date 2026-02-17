# mbentley/omada-controller

Docker image for [TP-Link Omada Software Controller](https://support.omadanetworks.com/us/product/omada-software-controller/) (also known as TP-Link Omada Network Application) to centrally manage [TP-Link Omada Hardware](https://www.omadanetworks.com/en/business-networking/all-omada/).

> [!NOTE]
> **Disclaimer**: I am not, in any way, affiliated with TP-Link. I am just a community member who has packaged TP-Link's free software as a Docker image for easier management and consumption.

For instructions on running a legacy v3 or v4 controller, see the [README for v3 and v4](README_v3_and_v4.md). See the tag [archive_v3_v4](https://github.com/mbentley/docker-omada-controller/releases/tag/archive_v3_v4) for a snapshot of the code that includes the v3 and v4 artifacts as they have been removed as of July 2, 2024.

## Table of Contents

* [Quickstart Guide](#quickstart-guide)
* [v5 to v6 Upgrade Guide](#v5-to-v6-upgrade-guide)
* [Image Tags](#image-tags)
    * [Multi-arch Tags](#multi-arch-tags)
    * [Explicit Architecture Tags](#explicit-architecture-tags)
    * [Explicit Version Tags](#explicit-version-tags)
    * [Tags for Beta/Testing](#tags-for-betatesting)
    * [Archived Tags](#archived-tags)
        * [Tags with Chromium](#tags-with-chromium)
* [Getting Help \& Reporting Issues](#getting-help--reporting-issues)
* [Best Practices for Operation](#best-practices-for-operation)
    * [Controller Backups](#controller-backups)
    * [Controller Upgrades](#controller-upgrades)
    * [Preventing Database Corruption](#preventing-database-corruption)
* [Building Images](#building-images)
    * [`amd64`](#amd64)
    * [`arm64`](#arm64)
    * [`armv7l`](#armv7l)
* [Example Usage](#example-usage)
    * [Using `net=host`](#using-nethost)
    * [Using port mapping](#using-port-mapping)
    * [Using non-default ports](#using-non-default-ports)
    * [Running Rootless](#running-rootless)
    * [Using Docker Compose](#using-docker-compose)
    * [Using k8s](#using-k8s)
        * [Kubernetes Helm Chart](#kubernetes-helm-chart)
        * [Kubernetes Manifests](#kubernetes-manifests)
* [Optional Environment Variables](#optional-environment-variables)
* [Persistent Data](#persistent-data)
* [Custom SSL Certificates](#custom-ssl-certificates)
* [Time Zones](#time-zones)
* [Unprivileged Ports](#unprivileged-ports)
* [Omada Controller API Documentation](#omada-controller-api-documentation)
* [Known Issues](KNOWN_ISSUES.md#known-issues)
    * [Controller Software Issues](KNOWN_ISSUES.md#controller-software-issues)
        * [Devices Fail to Adopt](KNOWN_ISSUES.md#devices-fail-to-adopt)
    * [Containerization Issues](KNOWN_ISSUES.md#containerization-issues)
        * [MongoDB Corruption](KNOWN_ISSUES.md#mongodb-corruption)
        * [Notes for `armv7l`](KNOWN_ISSUES.md#notes-for-armv7l)
            * [:warning: Unsupported Base Image for `armv7l`](KNOWN_ISSUES.md#unsupported-base-image-for-armv7l)
            * [:warning: Unsupported MongoDB](KNOWN_ISSUES.md#unsupported-mongodb)
        * [Low Resource Systems](KNOWN_ISSUES.md#low-resource-systems)
        * [Mismatched Userland and Kernel](KNOWN_ISSUES.md#mismatched-userland-and-kernel)
    * [Upgrade Issues](KNOWN_ISSUES.md#upgrade-issues)
        * [5.8 - 404s and Blank Pages](KNOWN_ISSUES.md#58---404s-and-blank-pages)
        * [Incorrect CMD](KNOWN_ISSUES.md#incorrect-cmd)
        * [5.12 - Unable to Login After Upgrade](KNOWN_ISSUES.md#512---unable-to-login-after-upgrade)
        * [Slowness in Safari](KNOWN_ISSUES.md#slowness-in-safari)
        * [5.14 - Controller Unable to Start](KNOWN_ISSUES.md#514---controller-unable-to-start)
        * [5.15 - Controller Unable to Start](KNOWN_ISSUES.md#515---controller-unable-to-start)

## Quickstart Guide

If you don't know much about Docker or want to just get started as easily as possible, start here as this will guide you through this readme on key concepts and things you want to take into consideration.

1. **Docker**
    * This guide assumes that you have Docker installed. If you don't, I would suggest starting [here](https://www.docker.com/get-started/).
1. **Verifying your CPU supports the required features for v6 of the image and above**
    * Due to the MongoDB 8 system requirements, specific CPU features are required to run v6 of the controller image and above.
    * Included in this repo is a shell script ([mongodb8_cpu_support_check.sh](./mongodb8_cpu_support_check.sh)) which can be executed to test for the required CPU features
    * If this script indicates that your CPU is not supported, check out the [KNOWN ISSUES section on this for clean installs](./KNOWN_ISSUES.md#clean-install) for how you can proceed with the v6 controller image.
1. **Picking an image tag**
    * `major` version tagged - For people who want to set it and forget it (i.e. - if you are used to just using `latest`), there is also the major tag version (i.e. - `5`, `6`, etc) which should be mostly safe from non-breaking changes.
    * `major.minor` version tagged - Most people will want to use a major.minor tag version (i.e. - `6.1`) as this is the safest option and can almost certainly be considered to be non-breaking when a new version of the image is available.
    * **USING THE `latest` TAG IS A BAD IDEA - DO NOT DO IT!** Using `latest` with software like this is not a good idea because you may upgrade to a version that your devices do not support and TP-Link can put in breaking changes at any time! Instead, use one of the two tag types above.
    * ~~If you need to create PDF reports from the controller, there are [tags with Chromium](#tags-with-chromium) as that is required to generate them. Those images are much larger and only available for `amd64` so only use them if you really need that functionality.~~ Reports are now CSV and XLSX so they do not require Chromium.
1. **Picking your networking mode**
    * There are three main options regarding how your container is exposed to your network, which is required to manage your TP-Link Omada enabled devices:
        * [Host network driver](#using-nethost) - this is the best and easiest option as it exposes the container using your Docker host's network interface as if you were running the controller outside of a container.
        * [Bridge network driver](#using-port-mapping) - this is also referred to just as using port mapping where the container runs on it's own isolated network. Many applications work fine in this mode but with the Omada Controller, this makes things more difficult due to how discovery works of TP-Link Omada enabled devices. I would advise against using this method unless you have a good reason to do so as you will need to manually configure your devices to know where the controller is running before they can be adopted (see the FAQ in the link shared)
        * **macvlan** - this is not covered by this guide as it's a more advanced topic - if you know how and when to use macvlan, I shouldn't have to explain it. If you want to learn, there are several GitHub issues in this repo where macvlan is discussed.
1. **How to manage your persistent data**
    * The data for the controller needs to be persisted outside of the container so that your configuration and settings are not lost between restarts, upgrades, etc. See [Persistent Data](#persistent-data) for details on what directories are important for maintaining your persistent data.
    * There are two main ways to persist data: in Docker managed volumes (which the examples use) or bind mounts. See the Docker docs on [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/) for details on how that works.
1. **How to run the container**
    * There are several ways to run your controller container:
        * [docker run...](#example-usage)
            * Examples for both host (_preferred_) and bridge network modes
            * Uses the latest major.minor (i.e. - `6.1`) tag
            * Only requires Docker to be set up
        * [docker compose](#using-docker-compose)
            * Examples for both host (_preferred_) and bridge network modes
            * Uses the latest major.minor (i.e. - `6.1`) tag
            * Requires Docker and [Docker Compose](https://docs.docker.com/compose/) to be set up
        * [k8s](#using-k8s)
            * Deployment is k8s is an advanced topic; only use this if you know what you are doing and can support yourself.
        * **3rd party services**
            * There are many 3rd party container marketplaces built into NAS devices or other appliances which can simplify the deployment - see those specific tools for instructions as that is beyond the scope of this guide.
1. **Controller Maintenance and Operations**
    * [Controller Backups](#controller-backups) - how to configure and take backups
    * [Controller Upgrades](#controller-upgrades) - how to upgrade the controller by updating the image
    * [How to properly stop the controller](#preventing-database-corruption) - how to cleanly stop the container to prevent database corruption
1. **Accessing the Controller**
    * Once deployed, the Omada Controller will be available on `https://<ip-address-or-hostname>:8043/`, assuming you're using the default ports.
1. **Have further questions?**
    * Open a [Discussion in the Help category](https://github.com/mbentley/docker-omada-controller/discussions/categories/help) and the community will give you a hand, when they are able.

## v5 to v6 Upgrade Guide

There are three main options for upgrading from v5 to v6:

1. **MongoDB Upgrade Container** - run the MongoDB upgrade container (process described below)
1. **Controller Migration** - stand up a new v6 controller along side your v5 controller and use the built in migration tool within the Omada Controller
1. **Controller Backup & Restore** - take a backup through the Omada Controller application from your v5 controller, start up a brand new v6 controller with all new persistent data directories and restore your v5 configuration file

This upgrade guide will focus on using the MongoDB upgrade container. The native controller migration and backup & restore procedures are using built in controller capabilities so you should follow TP-Link documentation but those details are out of scope of this guide.

> [!IMPORTANT]
> The upgrade requires a manual step of a MongoDB upgrade which is automated but it has to be run as a separate container while the controller is **stopped**.

There are a few reasons for the manual upgrade:

* The base OS image needs to be updated as Ubuntu 20.04 is no longer receiving security updates
* MongoDB 8 currently receives updates and is supposed to be more reliable and perform better than the old 3.6 version
* In order to upgrade MongoDB, it has to be done in steps and to make the upgrade from 3.6 to 8, many versions have to be executed and there are VERY specific operating system versions that support all of the needed versions which allows the complete upgrade to be done in one manual container run

Now that you understand why there is manual step required, see [the MongoDB upgrade guide](./mongodb_upgrade/) for detailed instructions on how to proceed with the upgrade.

If you tried to run the v6 controller without doing the upgrade, see [HELP! My Controller Stopped Working!](./mongodb_upgrade/#help-my-controller-stopped-working) for steps to get back to a working state or what you need to do to get back to a state where you can perform the upgrade.

## Image Tags

For every version at any given point in time, there are many different tags: `major`, `major.minor`, and a full `major.minor.patch.build` tag. For guidance on what image tag you should use, check out the _Picking an image tag_ section of the [quickstart guide](#quickstart-guide) above but the gist of it is that most people will want to use either a `major` or `major.minor` version tag.

### Multi-arch Tags

For a full tag list, search the [Docker Hub tags list](https://hub.docker.com/r/mbentley/omada-controller/tags). The following tags have multi-arch support for `amd64` and `arm64` and will automatically pull the correct tag based on your system's architecture:

| Tag(s) | Major.Minor Release | Current Version |
| :----- | ------------------- | --------------- |
| `6`, `6.1` | `6.1.x` | `6.1.0.19` |
| `6.0` | `6.0.x` | `6.0.0.25` |
| `latest`, `5`, `5.15` | `5.15.x` | `5.15.24.19` |

### Explicit Architecture Tags

If for some reason you can't use the multi-arch tags, there are explicitly tagged images with the architecture (`-amd64` and `-arm64`) appended to them. Check [Docker Hub](https://hub.docker.com/r/mbentley/omada-controller/tags) for the full list of tags.

### Explicit Version Tags

If you need a specific version of the controller, starting with 5.13 and 5.14, there are explicitly tagged images with the exact version (i.e. - `6.1.0.19`) in the tag name. Check [Docker Hub](https://hub.docker.com/r/mbentley/omada-controller/tags) for the full list of tags.

### Tags for Beta/Testing

These are multi-arch tags. For the full tag listings, see the Docker Hub tags above but the general format for `beta-*` and `*-openj9` follow for the specific architecture tags. OpenJ9 images are only available for `amd64` and `arm64`.

| Tag(s) | Major.Minor Release | Current Version |
| :----- | ------------------- | --------------- |
| `beta`, `beta-6.2`, `beta-6.2.0.12` | `6.2.x` Beta | `6.2.0.12` |
| `beta-openj9`, `beta-6.2-openj9`, `beta-6.2.0.12-openj9` | `6.2.x` Beta w/OpenJ9 | `6.2.0.12` |
| --- | --- | --- |
| `6-openj9`, `6.1-openj9`, `6.1.0.19-openj9` | `6.1.x` w/OpenJ9 | `6.1.0.19` |
| `6.0-openj9`, `6.0.0.25-openj9` | `6.0.x` w/OpenJ9 | `6.0.0.25` |
| `5.15-openj9`, `5.15.24.19-openj9` | `5.15.x` w/OpenJ9 | `5.15.24.19` |

## Archived Tags

> [!WARNING]
> Do **NOT** run the `armv7l` (32 bit) images. Upgrade your operating system to `arm64` (64 bit) unless you accept that you're running an outdated MongoDB, a base operating system with unpatched vulnerabilities, an old version of Java, and a controller that will never be upgraded beyond `5.15.8.2`! See the [Known Issues readme](KNOWN_ISSUES.md#notes-for-armv7l) for more information.

These images are still published on Docker Hub but are no longer regularly updated due to the controller software no longer being updated. **Use with extreme caution as these images are likely to contain unpatched security vulnerabilities!**. See [Archived Tags for v3 and v4](README_v3_and_v4.md#archived-tags) for details on the old, unmaintained image tags.

| Tag(s) | Major.Minor Release | Current Version |
| :----- | ------------------- | ----------------|
| `5.14` | `5.14.x` | `5.14.32.4` |
| `5.14-openj9`, `5.14.32.4-openj9` | `5.14.x` w/OpenJ9 | `5.14.32.4` |
| `5.13` | `5.13.x` | `5.13.30.8` |
| `5.13-chromium` | `5.13.x` | `5.13.30.8` |
| `5.13-openj9`, `5.13.30.8-openj9` | `5.13.x` w/OpenJ9 | `5.13.30.8` |
| `5.12` | `5.12.x` | `5.12.7` |
| `5.12-chromium` | `5.12.x` | `5.12.7` |
| `5.9` | `5.9.x` | `5.9.31` |
| `5.9-chromium` | `5.9.x` | `5.9.31` |
| `5.8` | `5.8.x` | `5.8.4` |
| `5.8-chromium` | `5.8.x` | `5.8.4` |
| `5.7` | `5.7.x` | `5.7.4` |
| `5.7-chromium` | `5.7.x` | `5.7.4` |
| `5.6` | `5.6.x` | `5.6.3` |
| `5.6-chromium` | `5.6.x` | `5.6.3` |
| `5.5` | `5.5.x` | `5.5.6` |
| `5.5-chromium` | `5.5.x` | `5.5.6` |
| `5.4` | `5.4.x` | `5.4.6` |
| `5.4-chromium` | `5.4.x` | `5.4.6` |
| `5.3` | `5.3.x` | `5.3.1` |
| `5.3-chromium` | `5.3.x` | `5.3.1` |
| `5.1` | `5.1.x` | `5.1.7` |
| `5.1-chromium` | `5.1.x` | `5.1.7` |
| `5.0` | `5.0.x` | `5.0.30` |

### Tags with Chromium

Going forward, Chromium is no longer required as of 5.14. If you were using a Chromium tag, go back to a normal tag. All reports should now either by CSV or XLSX format.

## Getting Help & Reporting Issues

If you have issues running the controller, feel free to [create a Help discussion](https://github.com/mbentley/docker-omada-controller/discussions/categories/help) and I will help as I can. If you are specifically having a problem that is related to the actual software, I would suggest filing an issue on the [TP-Link community forums](https://community.tp-link.com/en/business/forum/582) or [contacting TP-Link's support team](https://www.tp-link.com/en/support/) as I do not have access to source code to debug those issues. If you're not sure where the problem might be, I can help determine if it is a running in Docker issue or a software issue. If you're certain you have found a bug, create a [Bug Report Issue](https://github.com/mbentley/docker-omada-controller/issues/new/choose).

## Best Practices for Operation

### Controller Backups

While you can take backups of your controller by making a copy of the persistent data, the chance of data corruption exists if you do so while the container is running as there is a database used for persistence. The best way to take backups is to use the automatic backup capabilities within the controller itself. Go to `Settings` > `Maintenance` > `Backup` and scroll down to `Auto Backup` to enable and configure the feature. These backups can be restored as a part of the installation process on a clean controller install. If you do not see `Settings` > `Maintenance`, you may be drilled down into a sites' configuration. Make sure you're in the Global view as settings that impact the controller as a whole, like backups, are in that Global view.

Backups can also be taken manually on the same screen as the auto backup settings. This would be ideal to do before you perform an upgrade to ensure that you are able to roll back in case of issues upon upgrade as you can not move from a newer version of the controller to an older version! It will break the database and require you to do a full reinstall!

If you do want to just take a snapshot of your persistent data, make sure you stop the container cleanly, tar/zip/snapshot the data in some way, and then start the container back up to bring the controller back online.

### Controller Upgrades

Before performing any upgrade, I would suggest taking a backup through the controller itself. Controller upgrades are done by stopping the existing container gracefully (see the [note below](#preventing-database-corruption) on this topic), removing the existing container, and running a new container with the new version of the controller. This can be done manually, with compose, or with many other 3rd party tools which auto-update containers, such as [Watchtower](https://containrrr.dev/watchtower/).

### Preventing Database Corruption

When stopping your container in order to upgrade the controller, make sure to allow the MongoDB enough time to safely shutdown. This is done using `docker stop -t <value>` where `<value>` is a number in seconds, such as 60, which should allow the controller to cleanly shutdown. Database corruption has been observed when not cleanly shut down. The `docker run` and compose examples now include `--stop-timeout` and `stop_grace_period` which are set to 60s.

## Building Images

There are pre-built [images on Docker Hub](https://hub.docker.com/r/mbentley/omada-controller/tags) - you only need to build your own image if you either don't trust pre-built images or want to do something custom to the image.

<details>
<summary>Click to expand docker build instructions</summary>

There are some differences between the build steps for `amd64`, `arm64`, and `armv7l`. These changes will happen automatically if you use the build-args `INSTALL_VER` and `ARCH`. For possible `INSTALL_VER` values, see [mbentley/docker-omada-controller-url](https://github.com/mbentley/docker-omada-controller-url/blob/master/omada_ver_to_url.sh):

### `amd64`

  No build args required; set for the default build-args

  ```
  docker build \
    --build-arg BASE=mbentley/ubuntu:24.04 \
    --build-arg INSTALL_VER="6.1.0.19" \
    --build-arg ARCH="amd64" \
    -f Dockerfile \
    -t mbentley/omada-controller:6.1-amd64 .
  ```

### `arm64`

  Only the `ARCH` build-arg is required

  ```
  docker build \
    --build-arg BASE=mbentley/ubuntu:24.04 \
    --build-arg INSTALL_VER="6.1.0.19" \
    --build-arg ARCH="arm64" \
    -f Dockerfile \
    -t mbentley/omada-controller:6.1-arm64 .
  ```

### `armv7l`

  > [!WARNING]
  > The `armv7l` version was deprecated and support has been removed for versions beyond `5.15.8.2`.

  Both the `ARCH` and `BASE` build-args are required

  ```
  docker build \
    --build-arg INSTALL_VER="5.15.8.2" \
    --build-arg ARCH="armv7l" \
    --build-arg BASE="ubuntu:16.04" \
    -f Dockerfile \
    -t mbentley/omada-controller:5.15-armv7l .
  ```

</details>

## Example Usage

These example below are based on `docker run...` commands. See [Using Docker Compose](#using-docker-compose) for compose examples or [Using k8s](#using-k8s) for example k8s manifests. See [Optional Environment Variables](#optional-environment-variables) for details on the environment variables that can modify the behavior of the controller inside the container. To run this Docker image and keep persistent data in named volumes:

### Using `net=host`

Using host networking mode is the preferred method of running the controller. In order to use the host's network namespace, you must first ensure that there are not any port conflicts. The `docker run` command is the same except for that all of the published ports should be removed and `--net host` should be added. Technically it will still work if you have the ports included, but Docker will just silently drop them. Here is a snippet of what the above should be modified to look like:

```bash
docker run -d \
  --name omada-controller \
  --stop-timeout 60 \
  --restart unless-stopped \
  --ulimit nofile=4096:8192 \
  --net host \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:6.1
```

### Using port mapping

When is comes to device management, using port mapping is more complex than using host networking as your devices need to be informed of the controller's IP or hostname. For instructions on how to configure your device for adoption, see [the device adoption readme](./DEVICE_ADOPTION.md). If you do not follow these instructions, it is highly likely that new devices will fail to adopt!

> [!WARNING]
> If you want to change the controller ports from the default mappings, you *absolutely must* update the port binding inside the container via the environment variables. The ports exposed must match what is inside the container. The Omada Controller software expects that the ports are the same inside the container and outside and will load a blank page if that is not done. See [#99](https://github.com/mbentley/docker-omada-controller/issues/99#issuecomment-821243857) for details and and example of the behavior.

```bash
docker run -d \
  --name omada-controller \
  --stop-timeout 60 \
  --restart unless-stopped \
  --ulimit nofile=4096:8192 \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 19810:19810/udp \
  -p 27001:27001/udp \
  -p 29810:29810/udp \
  -p 29811-29817:29811-29817 \
  -e TZ=Etc/UTC \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller:6.1
```

### Using non-default ports

> [!TIP]
> tl;dr - Always make sure the environment variables for the ports match any changes you have made in the web UI and you'll be fine.

If you want to change the ports of your Omada Controller to something besides the defaults, there is some unexpected behavior that the controller exhibits. There are two sets of ports: one for HTTP/HTTPS for the controller itself and another for HTTP/HTTPS for the captive portal, typically used for authentication to a guest network. The controller's set of ports, which are set by the `MANAGE_*_PORT` environment variables, can only be modified using the environment variables on the first time the controller is started. If persistent data exists, changing the controller's ports via environment variables will have no effect on the controller itself and can only be modified through the web UI. On the other hand, the portal ports will always be set to whatever has been set in the environment variables, which are set by the `PORTAL_*_PORT` environment variables.

If you absolutely need to have the ports re-read from the environment variables, you can set the `WEB_CONFIG_OVERRIDE` environment variable to `true` and they'll be re-read on next startup.

### Running Rootless

There is an optional ability to run the container in a rootless mode. This version has fewer pre-flight capabilities to do tasks like set permissions for you but works in environments where running containers as root is blocked (i.e. - many Kubernetes environments). To activate the [rootless entrypoint](entrypoint-rootless.sh) the following conditions must be met:

* Set the environment variable `ROOTLESS` to `true`
* Set the actual UID/GID of the container to be your desired values (they must be numerical)
    * Note: the `PUID` and `PGID` variables do not apply here
* Set the appropriate ownership of your persistent data directories for `data` and `logs`
* Any additional files or data directories, such as the `/certs` path when injecting your own certificates, must be readable by the user in which you're running as

### Using Docker Compose

There are a few Docker Compose files available that can serve as a guide if you want to use compose to managed the lifecycle of your container. Depending on which network mode of operation you want to use, there are example for each: [host networking](./docker-compose.yml) or [bridge/port mapping](./docker-compose_bridge.yml).

```bash
<download the compose file you wish to use>
<edit the compose file to match your persistent data needs>
docker compose up -d
```

### Using k8s

There are two available options for deployment to Kubernetes:

* Kubernetes Helm chart (recommended)
* Kubernetes manifests

#### Kubernetes Helm Chart

The Helm charts are published to [mbentley/omada-controller-helm](https://hub.docker.com/r/mbentley/omada-controller-helm) on Docker Hub but are also available directly [from this repo](./helm/omada-controller-helm). For a Helm release list and detailed usage instructions, check out the [Helm chart's README](./helm/omada-controller-helm/README.md).

Examples of how to deploy a complete stack of MongoDB and Omada Controller using Helm can be found in the [k8s/helm](./k8s/helm/) directory.  Follow the [README](./k8s/helm/README.md) to get started. Review the values files to see how to configure the chart for your environment.

#### Kubernetes Manifests

The example manifests are in the [k8s/manifests](./k8s/manifests/) directory. It's assumed that you will know how to modify and use these manifests on k8s if you choose that as your deployment option.

## Optional Environment Variables

| Variable | Default | Values | Description | Valid For |
| :------- | :------ | :----: | :---------- | :-------: |
| `EAP_MONGOD_URI` | _null_ | `mongodb://user:pass@1.2.3.4:27017/omada` | Used to specify the URI of MongoDB when running it external to the controller container | >= `5.x` |
| `MANAGE_HTTP_PORT` | `8088` | `1024`-`65535` | Management portal HTTP port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) | >= `3.2` |
| `MANAGE_HTTPS_PORT` | `8043` | `1024`-`65535` | Management portal HTTPS port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) | >= `3.2` |
| `MONGO_EXTERNAL` | `false` | `true`, `false` | Disables MongoDB from starting inside the controller container; used for external MongoDB | >= 5.x |
| `PGID` | `508` | _any_ | Set the `omada` process group ID ` | >= `3.2` |
| `PGROUP` | `omada` | _any_ | Set the group name for the process group ID to run as | >= `5.0` |
| `PORTAL_HTTP_PORT` | `8088` | `1024`-`65535` | User portal HTTP port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) | >= `4.1` |
| `PORTAL_HTTPS_PORT` | `8843` | `1024`-`65535` | User portal HTTPS port; for ports < 1024, see [Unprivileged Ports](#unprivileged-ports) | >= `4.1` |
| `PORT_APP_DISCOVERY` | `27001` | `1024`-`65535` | Omada Controller can be discovered by the Omada APP within the same network through this port | >= `5.x` |
| `PORT_DISCOVERY` | `29810` | `1024`-`65535` | Omada Controller and Omada Discovery Utility discover Omada devices | >= `5.x` |
| `PORT_MANAGER_V1` | `29811` | `1024`-`65535` | Omada Controller and Omada Discovery Utility manage the Omada devices running firmware fully adapted to Omada Controller v4* | >= `5.x` |
| `PORT_ADOPT_V1` | `29812` | `1024`-`65535` | Omada Controller and Omada Discovery Utility manage the Omada devices running firmware fully adapted to Omada Controller v4* | >= `5.x` |
| `PORT_UPGRADE_V1` | `29813` | `1024`-`65535` | When upgrading the firmware for the Omada devices running firmware fully adapted to Omada Controller v4*. | >= `5.x` |
| `PORT_MANAGER_V2` | `29814` | `1024`-`65535` | Omada Controller and Omada Discovery Utility manage the Omada devices running firmware fully adapted to Omada Controller v5* | >= `5.x` |
| `PORT_TRANSFER_V2` | `29815` | `1024`-`65535` | Omada Controller receives Device Info and Packet Capture files from the Omada devices | >= `5.9` |
| `PORT_RTTY` | `29816` | `1024`-`65535` | Omada Controller establishes the remote control terminal session with the Omada devices | >= `5.9` |
| `PORT_DEVICE_MONITOR` | `29817` | `1024`-`65535` | Omada Controller ??? (currently unknown the full purpose) | >= `06.0` |
| `PUID` | `508` | _any_ | Set the `omada` process user ID ` | >= `3.2` |
| `PUSERNAME` | `omada` | _any_ | Set the username for the process user ID to run as | >= `5.0` |
| `ROOTLESS` | `false` | `true`, `false` | Sets the entrypoint for [rootless mode](#running-rootless) | >= `5.14` |
| `SHOW_SERVER_LOGS` | `true` | `true`, `false` | Outputs Omada Controller logs to STDOUT at runtime | >= `4.1` |
| `SHOW_MONGODB_LOGS` | `false` | `true`, `false` | Outputs MongoDB logs to STDOUT at runtime | >= `4.1` |
| `SKIP_USERLAND_KERNEL_CHECK` | `false` | `true`, `false` | When set to `true`, skips the userland/kernel match check for `armv7l` & `arm64` | >= `3.2` |
| `SMALL_FILES` | `false` | `true`, `false` | See [Small Files](#small-files) for more detail; no effect in >= `4.1.x` | `3.2` only |
| `SSL_CERT_NAME` | `tls.crt` | _any_ | Name of the public cert chain mounted to `/cert`; see [Custom Certificates](#custom-certificates) | >= `3.2` |
| `SSL_KEY_NAME` | `tls.key` | _any_ | Name of the private cert mounted to `/cert`; see [Custom Certificates](#custom-certificates) | >= `3.2` |
| `TLS_1_11_ENABLED` | `false` | `true`, `false` | Re-enables TLS 1.0 & 1.1 if set to `true` | >= `4.1` |
| `TZ` | `Etc/UTC` | _\<many\>_ | See [Time Zones](#time-zones) for more detail | >= `3.2` |
| `UPGRADE_HTTPS_PORT` | `8043` | `1024`-`65535` | Dedicated HTTPS port for upgrades, separate from the main Controller port | >= `6.1` |
| `WEB_CONFIG_OVERRIDE` | `false` | `true`, `false` | Forces the controller to re-read port configuration from `omada.properties` on startup; see [Using non-default ports](#using-non-default-ports) | >= `5.x` |

Documentation on the ports used by the controller can be found in the [TP-Link FAQ](https://support.omadanetworks.com/us/document/13090/).

## Persistent Data

In the examples, there are two directories where persistent data is stored: `data` and `logs`. The `data` directory is where the persistent database data is stored where all of your settings, app configuration, etc is stored. The `log` directory is where logs are written and stored. I would suggest that you use a bind mounted volume for the `data` directory to ensure that your persistent data is directly under your control and of course take regular backups within the Omada Controller application itself. Previous versions of the controller (before 5.x) also used a `work` persistent directory `omada-work` which was mapped to `/opt/tplink/EAPController/work` inside the container where the application was deployed. This `work` directory is no longer needed as of 5.0.x.

## Custom SSL Certificates

By default, Omada software uses self-signed certificates. If however you want to use custom certificates you can mount them into the container as `/cert/tls.key` and `/cert/tls.crt`. The `tls.crt` file needs to include the full chain of certificates, i.e. cert, intermediate cert(s) and CA cert. This is compatible with kubernetes TLS secrets. Entrypoint script will convert them into Java Keystore used by jetty inside the Omada SW. If you need to use different file names, you can customize them by passing values for `SSL_CERT_NAME` and `SSL_KEY_NAME` as seen above in the [Optional Environment Variables](#optional-environment-variables) section.

> [!WARNING]
> As of the version 4.1, certificates can also be installed through the web UI. You should not attempt to mix certificate management methods as installing certificates via the UI will store the certificates in MongoDB and then the `/cert` volume method will cease to function. If you installed certificates using the UI and want to revert this - see [this discussion](https://github.com/mbentley/docker-omada-controller/discussions/527).

## Time Zones

By default, this image uses the `Etc/UTC` time zone. You may update the time zone used by passing a different value in the `TZ` variable. See [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) for a complete list of values in the `TZ identifier` table column.

## Unprivileged Ports

This Docker image runs as a non-root user by default. In order to bind unprivileged ports (ports < 1024 by default), you must include `--sysctl net.ipv4.ip_unprivileged_port_start=0` in your `docker run` command to allow ports below 1024 to be bound by non-root users.

## Omada Controller API Documentation

If you are interested in using the Omada Controller APIs to retrieve data from the controller, the latest version of the API documentation that I have found is available from the [community forums in this post](https://community.tp-link.com/en/business/forum/topic/590430). I'm not able to provide support for the APIs but I've found them to be helpful for my own usage and they weren't easy to find.

## Known Issues

See [the Known Issues](KNOWN_ISSUES.md) documentation for details.
