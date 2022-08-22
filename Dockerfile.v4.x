# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:18.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

COPY healthcheck.sh install.sh log4j_patch.sh /

# valid values: amd64 (default) | arm64 | armv7l
ARG ARCH=amd64

# install version (major.minor only); OMADA_URL set in install.sh
ARG INSTALL_VER="4.4"

# install omada controller (instructions taken from install.sh) & patch log4j, if applicable
RUN /install.sh &&\
  /log4j_patch.sh &&\
  rm /install.sh /log4j_patch.sh

COPY entrypoint-4.x.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8088 8043 8843 27001/udp 27002 29810/udp 29811 29812 29813
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-cp","/opt/tplink/EAPController/lib/*:","com.tplink.omada.start.OmadaLinuxMain"]
