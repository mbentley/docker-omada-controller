# Known Issues

* [Controller Software Issues](#controller-software-issues)
    * [Devices Fail to Adopt](#devices-fail-to-adopt)
* [Containerization Issues](#containerization-issues)
    * [MongoDB Corruption](#mongodb-corruption)
    * [Notes for `armv7l`](#notes-for-armv7l)
        * [:warning: Unsupported Base Image for `armv7l`](#unsupported-base-image-for-armv7l)
        * [:warning: Unsupported MongoDB](#unsupported-mongodb)
    * [Low Resource Systems](#low-resource-systems)
    * [Mismatched Userland and Kernel](#mismatched-userland-and-kernel)
* [Upgrade Issues](#upgrade-issues)
    * [5.8 - 404s and Blank Pages](#58---404s-and-blank-pages)
    * [Incorrect CMD](#incorrect-cmd)
    * [5.12 - Unable to Login After Upgrade](#512---unable-to-login-after-upgrade)
    * [Slowness in Safari](#slowness-in-safari)
    * [5.14 - Controller Unable to Start](#514---controller-unable-to-start)
    * [5.15 - Controller Unable to Start](#515---controller-unable-to-start)

## Controller Software Issues

### Devices Fail to Adopt

Users who are using `bridge` mode often report that switches and EAPs fail to adopt. This is due to the controller being technically being on a different network inside the container's bridge network, exporting the ports via NAT. Using port mapping is more complex than using host networking as your devices need to be informed of the controller's IP or hostname. See [this TP-Link FAQ](https://www.tp-link.com/us/support/faq/3087/) for details on how to configure this on your device(s) prior to attempting to adopt them.

## Containerization Issues

### MongoDB Corruption

While MongoDB is fairly robust, the persistent data can become corrupt if a clean shutdown isn't performed. By default, Docker only waits 10 seconds before killing the container processes when using `docker stop...`. I would **highly recommend** performing a stop with a large timeout value, such as `docker stop -t 30...` to ensure that the controller is cleanly shut down. This value may need to be even larger for low powered devices, such as a Raspberry Pi.

### Notes for `armv7l`

** ⚠ Deprecation and Removal Notice ⚠** - armv7l images will no longer be available starting with the v5.15.20 and later versions. See [this issue](https://github.com/mbentley/docker-omada-controller/issues/542) describing the change. The last version that will be available for `armv7l` is `5.15.8.2`.

**tl;dr** - Do not run the Omada Controller on your `armv7l`/`armhf` (32 bit arm) based operating system! If you're running as Raspberry Pi 3, 4, Pi Zero 2W, you should [run a 64 bit operating system](https://www.raspberrypi.com/news/raspberry-pi-os-64-bit/) so you can use the `arm64` image which is supported. At any time, TP-Link can break compatibility with 32 bit arm and there will be no upgrade path forward! You have been warned!

#### Unsupported Base Image for `armv7l`

All `armv7l` images are based on Ubuntu 16.04 due to the lack of packaging for MongoDB in newer Ubuntu releases. Ubuntu 16.04 is end of general support so security patches aren't regularly being released. I would highly recommend not using the `armv7l` images unless you have no other alternative and accept the security risk. If you are running a Raspberry Pi, I might suggest looking into running an `arm64` based operating system if your system supports it (the [Raspberry Pi 3 and above do](https://www.raspberrypi.com/news/raspberry-pi-os-64-bit/))

#### Unsupported MongoDB

The `armv7l` architecture is 32 bit and MongoDB is no longer available as a pre-compiled binary in Ubuntu, this means that the `armv7l` images are running version `2.6.10` of MongoDB. This may lead to unexpected behavior as TP-Link states Omada Controller version 4.1.x and newer require at least MongoDB `3.0.15` or newer, depending on which version of the controller you're running. For the `armv7l` architecture, I will continue to include those in the builds until they stop working as I can't guarantee that an update will not actually require a newer MongoDB feature that isn't available.

### Low Resource Systems

Systems such as Raspberry Pis may not have sufficient memory to run with the default memory settings of this image. If you system only has 1 GB of RAM, I would highly recommend adjusting the Xmx arguments by overriding the `CMD` [as seen in this issue here](https://github.com/mbentley/docker-omada-controller/issues/198#issuecomment-1100485810) to prevent the container from being OOM killed by the OS.

### Mismatched Userland and Kernel

If a Raspberry Pi 4 is running a 32 bit version of Raspberry Pi OS, a [recent firmware update](https://github.com/raspberrypi/firmware/issues/1795) has intentionally made it so the default kernel the Pi will boot from has been switched from 32 bit kernel to a 64 bit kernel. This is a problem for the running container because the version of MongoDB that is present in the `armv7l` image (also known as `armhf`), will fail to start on a 64 bit kernel. Most software tends to run fine when switching kernels but in this case, it will prevent the controller from running due to MongoDB failing to start. Please also review the [Notes for armv7l](#notes-for-armv7l) to also understand the risks for running the `armv7l` based controller!

To fix this issue in the short term, you will want to instruct your Pi to boot from a 32 bit kernel instead of the 64 bit kernel by:

1. Adding `arm_64bit=0` to the `/boot/config.txt` file
1. Rebooting the device

A proper long term solution would be to reinstall Raspberry Pi OS on your Pi 4 and use the new `arm64` based operating system which will get you a 64 bit userland and a 64 bit kernel. There are [significant known issues](#notes-for-armv7l) while running the `armv7l` image on a device so longer term, this is the best solution.

## Upgrade Issues

### 5.8 - 404s and Blank Pages

It has been reported that a number of users are seeing 404s or blank pages after upgrading to version 5.8. This can be resolved by either force-reloading the page or by clearing your browser's cache.

### Incorrect CMD

It has been reported that users of some NAS devices such as a Synology or users of a Docker management UI like Portainer have had issues with upgrades due to the CMD being retained between versions. This normally does not happen with the Docker command line so it is a bit of an unexpected pattern but it can not be overwritten as it exists outside of the container.

If updating from 3.x to 4.x or 4.x to 5.x, make sure to **completely** re-create the container (leaving your persistent data intact) otherwise the controller will not start. This is due to the CMD changing between the major releases as some web interfaces like Synology or Portainer retain the entrypoint and command explicitly instead of inheriting it from the image. To resolve the issue, do one of the following:

* Re-create the container - remove the container, keeping your persistent data and create it again using whatever method you used to originally create it.
* Update the CMD (command is all on one line):
    * 4.x to 5.x - `/usr/bin/java -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof -Djava.awt.headless=true -cp /opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties: com.tplink.smb.omada.starter.OmadaLinuxMain`

It should be noted that users of 3.x who wish to upgrade to 4.x must perform [specific upgrade steps](#upgrading-to-41-from-3210-or-below) to prevent data loss!

### 5.12 - Unable to Login After Upgrade

There is a [known bug](https://github.com/mbentley/docker-omada-controller/discussions/344#discussioncomment-7104908) in the controller software where a user is not able to login with their local user after upgrading to 5.12.x. This has been [reported to TP-Link](https://community.tp-link.com/en/business/forum/topic/623942) but a fix has not yet been provided.

### Slowness in Safari

In versions 5.8 to 5.12, it has been seen where Safari will take a significant amount of time to completely load a page in the controller web interface.  This is an [issue that has been reported upstream](https://community.tp-link.com/en/business/forum/topic/619304?replyId=1255404).

### 5.14 - Controller Unable to Start

Upon upgrade to 5.14, the controller may not start. You may see error messages that include phrases like: `Cannot retry start up springboot`, `Unsatisfied dependency expressed through field...`, `org.springframework.beans.factory.UnsatisfiedDependencyException`, among others. This is a problem with the controller software itself that TP-Link is aware of. If you're impacted, see the first post in [this issue](https://github.com/mbentley/docker-omada-controller/issues/418) for possible workaround instructions and more information. This issue should no longer be present on the latest 5.14 versions.

### 5.15.6.x - Controller Unable to Start

**Warning**: do **NOT** use this override environment variable unless you need it. It may cause unexpected issues in the future. Remove the environment variable if you're no longer running on 5.15.6.x. Upon upgrade to 5.15.6.x, the controller may not start. You may see error messages right around the `Valid radius server keystore is missing. Generating one ...` message that include phrases like: `Exception in thread "main" java.lang.NoSuchFieldError: id_alg_zlibCompress` among others. This is a problem with the controller software itself that TP-Link is aware of. If you're impacted, see the first post in [this issue](https://github.com/mbentley/docker-omada-controller/issues/509) for more information. An environment variable can be set as `WORKAROUND_509=true` on the container definition and it will delete two library files that are causing the issue.
