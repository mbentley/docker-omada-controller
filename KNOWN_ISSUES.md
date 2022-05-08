# Known Issues

## MongoDB Corruption

While MongoDB is fairly robust, the persistent data can become corrupt if a clean shutdown isn't performed.  By default, Docker only waits 10 seconds before killing the container processes when using `docker stop...`.  I would **highly recommend** performing a stop with a large timeout value, such as `docker stop -t 30...` to ensure that the controller is cleanly shut down.  This value may need to be even larger for low powered devices, such as a Raspberry Pi.

## Upgrade Issues

It has been reported that users of some NAS devices such as a Synology or users of a Docker management UI like Portainer have had issues with upgrades due to the CMD being retained between versions. This normally does not happen with the Docker command line so it is a bit of an unexpected pattern but it can not be overwritten as it exists outside of the container.

If updating from 3.x to 4.x or 4.x to 5.x, make sure to **completely** re-create the container otherwise the controller will not start. This is due to the CMD changing between the major releases as some web interfaces like Synology or Portainer retain the entrypoint and command explicitly instead of inheriting it from the image. To resolve the issue, do one of the following:

* Re-create the container - remove the container, keeping your persistent data and create it again using whatever method you used to originally create it.
* Update the CMD (command is all on one line):
  * 4.x to 5.x - `/usr/bin/java -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof -Djava.awt.headless=true -cp /opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties: com.tplink.smb.omada.starter.OmadaLinuxMain`

It should be noted that users of 3.x who wish to upgrade to 4.x must perform [specific upgrade steps](#upgrading-to-41-from-3210-or-below) to prevent data loss!

## Notes for `armv7l`

* **Base Image for `armv7l`** - All `armv7l` images are based on Ubuntu 16.04 due to the lack of packaging for mongodb in newer Ubuntu releases.  Ubuntu 16.04 is end of general support so security patches aren't regularly being released.  I would highly recommend not using the `armv7l` images unless you have no other alternative and accept the security risk.  If you are running a Raspberry Pi, I might suggest looking into running an `arm64` based operating system if your system supports it (the [Raspberry Pi 3 and above do](https://www.raspberrypi.com/news/raspberry-pi-os-64-bit/))
* **Low Resource Systems** - Systems such as Raspberry Pis may not have sufficient memory to run with the default memory settings of this image.  If you system only has 1 GB of RAM, I would highly recommend adjusting the Xmx arguments by overriding the `CMD` [as seen in this issue here](https://github.com/mbentley/docker-omada-controller/issues/198#issuecomment-1100485810) to prevent the container from being OOM killed by the OS.
