# mbentley/omada-controller

docker image based off of ubuntu:18.04 for [TP-Link Omada Controller](https://www.tp-link.com/en/products/details/EAP-Controller.html) to control [TP-Link Omada EAP Series Wireless Access Points](https://www.tp-link.com/en/omada/)

## Tags

* `latest`, `3.2` - Omada Controller 3.2.x (currently 3.2.6)
* `3.1` - Omada Controller 3.1.x (currently 3.1.13)
* `3.0` - Omada Controller 3.0.x (currently 3.0.5)

## Example usage

To run this Docker image and keep persistent data in named volumes:

```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -e TZ=Etc/UTC \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 27001:27001/udp \
  -p 27002:27002 \
  -p 29810:29180/udp \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller
```

## Time Zones

By default, this image used the `Etc/UTC` time zone.  You may update the time zone used by passing a different value in the `TZ` variable.  See [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) for a complete list of values in the `TZ database name` table column.

## Persistent Data and Permissions

If you utilize bind mounts instead of Docker named volumes (e.g. - `-v /path/to/data:/opt/tplink/EAPController/data`) in your run command, you will want to make sure that you have set the permissions appropriately on the filesystem otherwise you will run into permissions errors and the container will not run because it won't have the permissions to write data since this container uses a non-root user.  To resolve that, you need to `chown` the directory to `508:508` on the host as that is the UID and GID that we use inside the container.  For example:

```
chown -R 508:508 /data/omada/data /data/omada/work /data/omada/logs
```

