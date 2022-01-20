# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:18.04
FROM ${BASE}

LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"

ARG OMADA_VER=5.0.30
ARG OMADA_TAR="Omada_SDN_Controller_v${OMADA_VER}_linux_x64.tar.gz"
ARG OMADA_URL="https://static.tp-link.com/upload/software/2022/202201/20220120/${OMADA_TAR}"
# valid values: amd64 (default) | arm64 | armv7l
ARG ARCH=amd64

COPY install.sh healthcheck.sh /

# install omada controller (instructions taken from install.sh); then create a user & group and set the appropriate file system permissions
RUN /install.sh && rm /install.sh

# patch log4j vulnerability
COPY log4j_patch.sh /log4j_patch.sh
RUN /log4j_patch.sh

COPY entrypoint-5.x.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8088 8043 8843 29810/udp 29811 29812 29813 29814
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","-cp","/opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties:","com.tplink.smb.omada.starter.OmadaLinuxMain"]
