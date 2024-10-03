# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:20.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

COPY healthcheck.sh install.sh /

# valid values: amd64 (default) | arm64 | armv7l
ARG ARCH=amd64

# install version (major.minor or full version); OMADA_URL set in install.sh
ARG INSTALL_VER="5.14.26.1"
ARG NO_MONGODB=false

# install omada controller (instructions taken from install.sh)
RUN /install.sh &&\
  rm /install.sh

COPY entrypoint-5.x.sh /entrypoint.sh

# experiments for openj9 SCC creation
RUN --mount=type=tmpfs,destination=/opt/tplink/EAPController/data \
  --mount=type=tmpfs,destination=/opt/tplink/EAPController/logs \
  cd /opt/tplink/EAPController/data &&\
  mkdir db html keystore pdf &&\
  SCC_SIZE="50m" &&\
  unset OPENJ9_JAVA_OPTIONS &&\
  java -Xshareclasses:name=dry_run_scc,cacheDir=/opt/java/.scc,bootClassesOnly,nonFatal,createLayer -Xscmx$SCC_SIZE -version &&\
  export OPENJ9_JAVA_OPTIONS="-XX:+IProfileDuringStartupPhase -Xshareclasses:name=dry_run_scc,cacheDir=/opt/java/.scc,bootClassesOnly,nonFatal" &&\
  echo "SCC_SIZE: ${SCC_SIZE}";\
  java -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof -Djava.awt.headless=true --add-opens java.base/java.util=ALL-UNNAMED -cp /opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties: com.tplink.smb.omada.starter.OmadaLinuxMain &\
  sleep 60 &&\
  echo "SCC_SIZE: ${SCC_SIZE}";\
  echo "INFO: killing the java server process...";\
  kill $(pgrep java) &&\
  while pgrep java > /dev/null; do sleep 1; echo "INFO: still alive..."; done &&\
  echo "INFO: java server process has been killed" ;\
  FULL=$( (java -Xshareclasses:name=dry_run_scc,cacheDir=/opt/java/.scc,printallStats 2>&1 || true) | awk '/^Cache is [0-9.]*% .*full/ {print substr($3, 1, length($3)-1)}') &&\
  DST_CACHE=$(java -Xshareclasses:name=dry_run_scc,cacheDir=/opt/java/.scc,destroy 2>&1 || true) &&\
  SCC_SIZE=$(echo $SCC_SIZE | sed 's/.$//') &&\
  echo "SCC_SIZE: ${SCC_SIZE}";\
  echo "FULL: ${FULL}";\
  SCC_SIZE=$(awk "BEGIN {print int($SCC_SIZE * $FULL / 100.0)}") &&\
  if [ "${SCC_SIZE}" -eq 0 ]; then SCC_SIZE=1; fi &&\
  SCC_SIZE="${SCC_SIZE}m" &&\
  echo "NEW SCC_SIZE=${SCC_SIZE}";\
  echo "INFO: generate the SCC with an optimized size";\
  java -Xshareclasses:name=openj9_system_scc,cacheDir=/opt/java/.scc,bootClassesOnly,nonFatal,createLayer -Xscmx$SCC_SIZE -version &&\
  unset OPENJ9_JAVA_OPTIONS &&\
  export OPENJ9_JAVA_OPTIONS="-XX:+IProfileDuringStartupPhase -Xshareclasses:name=openj9_system_scc,cacheDir=/opt/java/.scc,bootClassesOnly,nonFatal" &&\
  java -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof -Djava.awt.headless=true --add-opens java.base/java.util=ALL-UNNAMED -cp /opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties: com.tplink.smb.omada.starter.OmadaLinuxMain &\
  sleep 60 &&\
  kill $(pgrep java) &&\
  while pgrep java > /dev/null; do sleep 1; done &&\
  FULL=$( (java -Xshareclasses:name=openj9_system_scc,cacheDir=/opt/java/.scc,printallStats 2>&1 || true) | awk '/^Cache is [0-9.]*% .*full/ {print substr($3, 1, length($3)-1)}'); \
  echo "SCC layer is $FULL% full." &&\
  if [ -d "/opt/java/.scc" ]; then \
    echo "CHMOD THIS"; \
    chmod -R 0777 /opt/java/.scc; \
  fi

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8088 8043 8843 29810/udp 29811 29812 29813 29814
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","--add-opens","java.base/java.util=ALL-UNNAMED","-cp","/opt/tplink/EAPController/lib/*::/opt/tplink/EAPController/properties:","com.tplink.smb.omada.starter.OmadaLinuxMain"]
