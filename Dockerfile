# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:24.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

COPY healthcheck.sh install.sh /

# valid values: amd64 (default) | arm64 | armv7l (deprecated)
ARG ARCH=amd64

# install version (major.minor or full version); OMADA_URL set in install.sh
ARG INSTALL_VER="6.0.0.25"
ARG NO_MONGODB=false

# install omada controller (instructions taken from install.sh)
RUN /install.sh &&\
  rm /install.sh

COPY entrypoint.sh entrypoint-rootless.sh /

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8088 8043 8843 19810/udp 27001/udp 29810/udp 29811 29812 29813 29814 29815 29816 29817
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","--add-opens","java.base/sun.security.x509=ALL-UNNAMED","--add-opens","java.base/sun.security.util=ALL-UNNAMED","-cp","/opt/tplink/EAPController/lib/*:/opt/tplink/EAPController/properties","com.tplink.smb.omada.starter.OmadaLinuxMain"]
