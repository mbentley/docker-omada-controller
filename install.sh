#!/usr/bin/env bash

set -e

OMADA_DIR="/opt/tplink/EAPController"
ARCH="${ARCH:-}"
OMADA_VER="${OMADA_VER:-}"
OMADA_TAR="${OMADA_TAR:-}"
OMADA_URL="${OMADA_URL:-}"
OMADA_MAJOR_VER="$(echo "${OMADA_VER}" | awk -F '.' '{print $1}')"

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

echo "ARCH=${ARCH}"
echo "OMADA_VER=${OMADA_VER}"
echo "OMADA_TAR=${OMADA_TAR}"
echo "OMADA_URL=${OMADA_URL}"

echo "**** Install Dependencies ****"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends -y "${PKGS[@]}"

echo "**** Download Omada Controller ****"
cd /tmp
wget -nv "${OMADA_URL}"

echo "**** Extract and Install Omada Controller ****"

# in the 4.4.3, 4.4.6, and 4.4.8 builds, they removed the directory. this case statement will handle variations in the build
case "${OMADA_VER}" in
  4.4.3|4.4.6|4.4.8)
    echo "version ${OMADA_VER}"
    mkdir "Omada_SDN_Controller_${OMADA_VER}"
    cd "Omada_SDN_Controller_${OMADA_VER}"
    tar zxvf "../${OMADA_TAR}"
    rm -f "../${OMADA_TAR}"
    ;;
  *)
    echo "not version 4.4.3/4.4.6/4.4.8"
    tar zxvf "${OMADA_TAR}"
    rm -f "${OMADA_TAR}"
    cd Omada_SDN_Controller_*
    ;;
esac

# make sure tha the install directory exists
mkdir "${OMADA_DIR}" -vp

# starting with 5.0.x, the installation has no webapps directory; these values are pulled from the install.sh
case "${OMADA_MAJOR_VER}" in
  5)
    NAMES=( bin data properties keystore lib install.sh uninstall.sh )
    ;;
  *)
    NAMES=( bin data properties keystore lib webapps install.sh uninstall.sh )
    ;;
esac

# copy over the files to the destination
for NAME in "${NAMES[@]}"
do
  cp "${NAME}" "${OMADA_DIR}" -r
done

# symlink for mongod
ln -sf "$(which mongod)" "${OMADA_DIR}/bin/mongod"
chmod 755 "${OMADA_DIR}"/bin/*

echo "**** Setup omada User Account ****"
groupadd -g 508 omada
useradd -u 508 -g 508 -d "${OMADA_DIR}" omada
mkdir "${OMADA_DIR}/logs" "${OMADA_DIR}/work"
chown -R omada:omada "${OMADA_DIR}/data" "${OMADA_DIR}/logs" "${OMADA_DIR}/work"

echo "**** Cleanup ****"
rm -rf /tmp/* /var/lib/apt/lists/*
