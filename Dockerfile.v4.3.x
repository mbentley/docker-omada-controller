# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:18.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"

COPY install.sh healthcheck.sh /
COPY entrypoint-4.x.sh /entrypoint.sh

# valid values: amd64 (default) | arm64 | armv7l
ARG ARCH=amd64
ARG OMADA_URL="https://static.tp-link.com/2021/202105/20210507/Omada_SDN_Controller_v4.3.5_linux_x64.tar.gz"

# install omada controller (instructions taken from install.sh); then create a user & group and set the appropriate file system permissions
RUN /install.sh && rm /install.sh

# patch log4j vulnerability
COPY log4j_patch.sh /
RUN /log4j_patch.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8088 8043 8843 27001/udp 27002 29810/udp 29811 29812 29813
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-cp","/opt/tplink/EAPController/lib/*:","com.tplink.omada.start.OmadaLinuxMain"]
