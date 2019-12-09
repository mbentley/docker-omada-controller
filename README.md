mbentley/omada-controller
=========================

docker image based off of ubuntu:18.04 for [TP-Link Omada Controller](https://www.tp-link.com/en/products/details/EAP-Controller.html) to control [TP-Link Omada EAP Series Wireless Access Points](https://www.tp-link.com/en/omada/)

## Tags
  * `latest`, `3.2` - Omada Controller 3.2.x (currently 3.2.4)
  * `3.1` - Omada Controller 3.1.x (currently 3.1.13)
  * `3.0` - Omada Controller 3.0.x (currently 3.0.5)

## Example usage
To run this Docker image and keep persistent data in named volumes:
```
docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller
```
