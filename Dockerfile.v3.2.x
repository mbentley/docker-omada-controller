# rebased/repackaged base image that only updates existing packages
FROM mbentley/ubuntu:18.04
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

ARG INSTALL_VER=3.2

# install omada controller (instructions taken from install.sh); then create a user & group and set the appropriate file system permissions
RUN \
  echo "**** Install Dependencies ****" &&\
  apt-get update &&\
  DEBIAN_FRONTEND="noninteractive" apt-get install -y gosu net-tools tzdata wget &&\
  rm -rf /var/lib/apt/lists/* &&\
  echo "**** Download Omada Controller ****" &&\
  cd /tmp &&\
  wget -nv "https://static.tp-link.com/upload/software/2022/202208/20220818/Omada_Controller_v3.2.17_Linux_x64.tar.gz" &&\
  echo "**** Extract and Install Omada Controller ****" &&\
  tar zxvf Omada_Controller_v3.2.17_Linux_x64.tar.gz &&\
  rm Omada_Controller_v3.2.17_Linux_x64.tar.gz &&\
  cd Omada_Controller_* &&\
  mkdir /opt/tplink/EAPController -vp &&\
  cp bin /opt/tplink/EAPController -r &&\
  cp data /opt/tplink/EAPController -r &&\
  cp properties /opt/tplink/EAPController -r &&\
  cp webapps /opt/tplink/EAPController -r &&\
  cp keystore /opt/tplink/EAPController -r &&\
  cp lib /opt/tplink/EAPController -r &&\
  cp install.sh /opt/tplink/EAPController -r &&\
  cp uninstall.sh /opt/tplink/EAPController -r &&\
  cp jre /opt/tplink/EAPController/jre -r &&\
  chmod 755 /opt/tplink/EAPController/bin/* &&\
  chmod 755 /opt/tplink/EAPController/jre/bin/* &&\
  echo "**** Cleanup ****" &&\
  cd /tmp &&\
  rm -rf /tmp/Omada_Controller*

# patch log4j vulnerability
COPY log4j_patch.sh /log4j_patch.sh
RUN /log4j_patch.sh &&\
  rm /log4j_patch.sh

COPY entrypoint-3.2.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

WORKDIR /opt/tplink/EAPController
EXPOSE 8088 8043 8843 29810/udp 29811 29812 29813 29814
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/tplink/EAPController/jre/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:-UsePerfData","-Deap.home=/opt/tplink/EAPController","-cp","/opt/tplink/EAPController/lib/*:","com.tp_link.eap.start.EapLinuxMain"]
