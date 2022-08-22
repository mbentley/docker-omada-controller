# rebased/repackaged base image that only updates existing packages
FROM mbentley/ubuntu:18.04
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

ARG INSTALL_VER=3.0

# install runtime dependencies
RUN apt-get update &&\
  apt-get install -y libcap-dev net-tools wget unzip &&\
  rm -rf /var/lib/apt/lists/*

# install omada controller (instructions taken from install.sh); then create a user & group and set the appropriate file system permissions
RUN cd /tmp &&\
  wget -nv "https://static.tp-link.com/2018/201811/20181108/Omada_Controller_v3.0.5_linux_x64.tar.gz.zip" &&\
  unzip Omada_Controller_v3.0.5_linux_x64.tar.gz.zip &&\
  rm Omada_Controller_v3.0.5_linux_x64.tar.gz.zip &&\
  tar zxvf Omada_Controller_v3.0.5_linux_x64.tar.gz &&\
  cd Omada_Controller_v3.0.5_linux_x64 &&\
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
  cd /tmp &&\
  rm -rf /tmp/Omada_Controller_v3.0.5_linux_x64 Omada_Controller_v3.0.5_linux_x64.tar.gz &&\
  groupadd -g 508 omada &&\
  useradd -u 508 -g 508 -d /opt/tplink/EAPController omada &&\
  mkdir /opt/tplink/EAPController/logs /opt/tplink/EAPController/work &&\
  chown -R omada:omada /opt/tplink/EAPController/data /opt/tplink/EAPController/logs /opt/tplink/EAPController/work

# patch log4j vulnerability
COPY log4j_patch.sh /log4j_patch.sh
RUN /log4j_patch.sh &&\
  rm /log4j_patch.sh

USER omada
WORKDIR /opt/tplink/EAPController
EXPOSE 8088 8043
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
CMD ["/opt/tplink/EAPController/jre/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:-UsePerfData","-Deap.home=/opt/tplink/EAPController","-cp","/opt/tplink/EAPController/lib/*:","com.tp_link.eap.start.EapLinuxMain"]
