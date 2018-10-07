FROM ubuntu:18.04
MAINTAINER Matt Bentley <mbentley@mbentley.net>

RUN apt-get update &&\
  apt-get install -y libcap-dev net-tools wget &&\
  rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/docker.list

RUN cd /tmp &&\
  wget https://static.tp-link.com/2018/201809/20180907/Omada_Controller_V3.0.2_Linux_x64_targz.tar.gz &&\
  tar zxvf Omada_Controller_V3.0.2_Linux_x64_targz.tar.gz &&\
  cd Omada_Controller_V3.0.2_Linux_x64_targz &&\
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
  rm -rf /tmp/Omada_Controller_V3.0.2_Linux_x64_targz Omada_Controller_V3.0.2_Linux_x64_targz.tar.gz

RUN groupadd -g 508 omada &&\
  useradd -u 508 -g 508 -d /opt/tplink/EAPController omada &&\
  mkdir /opt/tplink/EAPController/logs /opt/tplink/EAPController/work &&\
  chown -R omada:omada /opt/tplink/EAPController/data /opt/tplink/EAPController/logs /opt/tplink/EAPController/work

USER omada
WORKDIR /opt/tplink/EAPController
EXPOSE 8088 8043
CMD ["/opt/tplink/EAPController/jre/bin/java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-Deap.home=/opt/tplink/EAPController","-cp","/opt/tplink/EAPController/lib/*:","com.tp_link.eap.start.EapLinuxMain"]
