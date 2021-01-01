#!/usr/bin/env bash

set -e

OMADA_DIR=/opt/tplink/EAPController

die() { echo -e "$@" 2>&1; exit 1; }

# common package dependencies
PKGS=(
  gosu
  net-tools
  openjdk-8-jre-headless
  tzdata
  wget
)

case "${ARCH}" in
amd64|arm64|"")
  PKGS+=( mongodb-server-core )
  ;;
armv7l)
  PKGS+=( mongodb )
  ;;
*)
  die "${ARCH}: unsupported ARCH"
  ;;
esac

echo "ARCH=$ARCH"
echo "OMADA_VER=$OMADA_VER"
echo "OMADA_TAR=$OMADA_TAR"
echo "OMADA_URL=$OMADA_URL"

#exit 0

echo "**** Install Dependencies ****"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends -y "${PKGS[@]}"

echo "**** Download Omada Controller ****"
cd /tmp
wget -nv ${OMADA_URL}

echo "**** Extract and Install Omada Controller ****"
tar zxvf ${OMADA_TAR}
rm -f ${OMADA_TAR}
cd Omada_SDN_Controller_*
mkdir ${OMADA_DIR} -vp
cp bin ${OMADA_DIR} -r
cp data ${OMADA_DIR} -r
cp properties ${OMADA_DIR} -r
cp webapps ${OMADA_DIR} -r
cp keystore ${OMADA_DIR} -r
cp lib ${OMADA_DIR} -r
cp install.sh ${OMADA_DIR} -r
cp uninstall.sh ${OMADA_DIR} -r
ln -sf $(which mongod) ${OMADA_DIR}/bin/mongod
chmod 755 ${OMADA_DIR}/bin/*

echo "**** Setup omada User Account ****"
groupadd -g 508 omada
useradd -u 508 -g 508 -d ${OMADA_DIR} omada
mkdir ${OMADA_DIR}/logs ${OMADA_DIR}/work
chown -R omada:omada ${OMADA_DIR}/data ${OMADA_DIR}/logs ${OMADA_DIR}/work

echo "**** Cleanup ****"
rm -rf /tmp/* /var/lib/apt/lists/*

