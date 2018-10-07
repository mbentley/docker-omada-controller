mbentley/omada-controller
=========================

docker image for TP-Link Omada Controller
based off of ubuntu:18.04

To pull this image:
`docker pull mbentley/omada-controller`

Example usage:
```
docker run -d --name omada-controller \
  -p 8088:8088 \
  -p 8043:8043 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-work:/opt/tplink/EAPController/work \
  -v omada-logs:/opt/tplink/EAPController/logs \
  mbentley/omada-controller
```
