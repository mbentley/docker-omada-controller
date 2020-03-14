FROM ubuntu:18.04
HEALTHCHECK --start-period=5m CMD wget --quiet --tries=1 --no-check-certificate http://127.0.0.1:8088 || exit 1
MAINTAINER Matt Bentley <mbentley@mbentley.net>

# Install java
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk

# Install mongodb
RUN apt-get update && \
    apt-get install -y mongodb

# install omada controller (instructions taken from install.sh); then create a user & group and set the appropriate file system permissions
RUN \
  echo "**** Install Dependencies ****" &&\
  apt-get update &&\
  DEBIAN_FRONTEND="noninteractive" apt-get install -y gosu net-tools tzdata wget &&\
  rm -rf /var/lib/apt/lists/* &&\
  echo "**** Download Omada Controller ****" &&\
  cd /tmp &&\
  wget -nv https://static.tp-link.com/2020/202001/20200116/Omada_Controller_v3.2.6_linux_x64.tar.gz &&\
  echo "**** Extract and Install Omada Controller ****" &&\
  tar zxvf Omada_Controller_v3.2.6_linux_x64.tar.gz &&\
  rm Omada_Controller_v3.2.6_linux_x64.tar.gz &&\
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
  chmod 755 /opt/tplink/EAPController/bin/* &&\
  echo "**** Cleanup ****" &&\
  cd /tmp &&\
  rm -rf /tmp/Omada_Controller* &&\
  echo "**** Setup omada User Account ****" &&\
  groupadd -g 508 omada &&\
  useradd -u 508 -g 508 -d /opt/tplink/EAPController omada &&\
  mkdir /opt/tplink/EAPController/logs /opt/tplink/EAPController/work &&\
  chown -R omada:omada /opt/tplink/EAPController/data /opt/tplink/EAPController/logs /opt/tplink/EAPController/work

# Replace with installed versions
RUN echo "*** Replacing bundled versions ***" && \
  rm -f /opt/tplink/EAPController/bin/mongod && \
  ln -s /usr/bin/mongod /opt/tplink/EAPController/bin/mongod && \
  rm -f /opt/tplink/EAPController/bin/mongo && \
  ln -s /usr/bin/mongod /opt/tplink/EAPController/bin/mongo && \
  rm -rf /opt/tplink/EAPController/jre && \
  ln -s /usr/lib/jvm/java-8-openjdk-arm64/jre /opt/tplink/EAPController/jre

# Remove mention of --nohttpinterface, which is not supported in MongoDB >= 3.6
RUN echo "*** Fixing properties ***" &&\
  sed -i -e 's/ --nohttpinterface//g' /opt/tplink/EAPController/properties/mongodb.properties

COPY entrypoint.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController
EXPOSE 8088 8043 27001/udp 27002 29810/udp 29811 29812 29813
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/work","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/tplink/EAPController/jre/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:-UsePerfData","-Deap.home=/opt/tplink/EAPController","-cp","/opt/tplink/EAPController/lib/*:","com.tp_link.eap.start.EapLinuxMain"]
