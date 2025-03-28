#!/bin/bash

set -e

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"

# PORTS CONFIGURATION
MANAGE_HTTP_PORT="${MANAGE_HTTP_PORT:-8088}"
MANAGE_HTTPS_PORT="${MANAGE_HTTPS_PORT:-8043}"
PORTAL_HTTP_PORT="${PORTAL_HTTP_PORT:-8088}"
PORTAL_HTTPS_PORT="${PORTAL_HTTPS_PORT:-8843}"
PORT_ADOPT_V1="${PORT_ADOPT_V1:-29812}"
PORT_APP_DISCOVERY="${PORT_APP_DISCOVERY:-27001}"
PORT_UPGRADE_V1="${PORT_UPGRADE_V1:-29813}"
PORT_MANAGER_V1="${PORT_MANAGER_V1:-29811}"
PORT_MANAGER_V2="${PORT_MANAGER_V2:-29814}"
PORT_DISCOVERY="${PORT_DISCOVERY:-29810}"
PORT_TRANSFER_V2="${PORT_TRANSFER_V2:-29815}"
PORT_RTTY="${PORT_RTTY:-29816}"
# END PORTS CONFIGURATION

# EXTERNAL MONGODB
MONGO_EXTERNAL="${MONGO_EXTERNAL:-false}"
EAP_MONGOD_URI="${EAP_MONGOD_URI:-mongodb://127.0.0.1:27217/omada}"
# escape & for eval
EAP_MONGOD_URI="$(eval echo "${EAP_MONGOD_URI//&/\\&}")"
# escape after eval as well for sed
EAP_MONGOD_URI="${EAP_MONGOD_URI//&/\\&}"
# END EXTERNAL MONGODB

SHOW_SERVER_LOGS="${SHOW_SERVER_LOGS:-true}"
SHOW_MONGODB_LOGS="${SHOW_MONGODB_LOGS:-false}"
SSL_CERT_NAME="${SSL_CERT_NAME:-tls.crt}"
SSL_KEY_NAME="${SSL_KEY_NAME:-tls.key}"
SKIP_USERLAND_KERNEL_CHECK="${SKIP_USERLAND_KERNEL_CHECK:-false}"

# set USER_ID and GROUP_ID variables
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

# make sure we aren't actually running as root
if [ "${USER_ID}" = "0" ] || [ "${GROUP_ID}" = "0" ]
then
  echo "ERROR: you're running as root (${USER_ID}:${GROUP_ID}); this defeats the purpose of running rootless!"
  exit 1
else
  echo "INFO: running as ${USER_ID}:${GROUP_ID}"
fi

# make sure the directories are writable
for DIR in /opt/tplink/EAPController/data /opt/tplink/EAPController/logs /opt/tplink/EAPController/properties /tmp
do
  if [ ! -w "${DIR}" ]
  then
    # notify user that the directory is not writable
    echo "ERROR: ${DIR} is not writable!"
    exit 1
  fi
done

# check if properties file exists; create it if it is missing
DEFAULT_FILES="/opt/tplink/EAPController/properties.defaults/*"
for FILE in ${DEFAULT_FILES}
do
  BASENAME=$(basename "${FILE}")
  if [ ! -f "/opt/tplink/EAPController/properties/${BASENAME}" ]
  then
    echo "INFO: Properties file '${BASENAME}' missing, restoring default file..."
    cp "${FILE}" "/opt/tplink/EAPController/properties/${BASENAME}"
    chown "${USER_ID}:${GROUP_ID}" "/opt/tplink/EAPController/properties/${BASENAME}"
  fi
done

# make sure that the html directory exists
if [ ! -d "/opt/tplink/EAPController/data/html" ] && [ -f "/opt/tplink/EAPController/data-html.tar.gz" ]
then
  # missing directory; extract from original
  echo "INFO: Report HTML directory missing; extracting backup to '/opt/tplink/EAPController/data/html'"
  tar zxvf /opt/tplink/EAPController/data-html.tar.gz -C /opt/tplink/EAPController/data
  chown -R "${USER_ID}:${GROUP_ID}" /opt/tplink/EAPController/data/html
fi

# make sure that the pdf directory exists
if [ ! -d "/opt/tplink/EAPController/data/pdf" ]
then
  # missing directory; extract from original
  echo "INFO: Report PDF directory missing; creating '/opt/tplink/EAPController/data/pdf'"
  mkdir /opt/tplink/EAPController/data/pdf
  chown -R "${USER_ID}:${GROUP_ID}" /opt/tplink/EAPController/data/pdf
fi

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown "${USER_ID}:${GROUP_ID}" /opt/tplink/EAPController/data/db
  echo "done"
fi

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# set values in omada.properties
# update stored ports when different of enviroment defined ports (works for numbers only)
for ELEM in MANAGE_HTTP_PORT MANAGE_HTTPS_PORT PORTAL_HTTP_PORT PORTAL_HTTPS_PORT PORT_ADOPT_V1 PORT_APP_DISCOVERY PORT_UPGRADE_V1 PORT_MANAGER_V1 PORT_MANAGER_V2 PORT_DISCOVERY PORT_TRANSFER_V2 PORT_RTTY
do
  # convert element to key name
  KEY="$(echo "${ELEM}" | tr '[:upper:]' '[:lower:]' | tr '_' '.')"

  # get value we want to set from the element
  END_VAL=${!ELEM}

  # get the current value from the omada.properties file
  STORED_PROP_VAL=$(grep -Po "(?<=${KEY}=)([0-9]+)" /opt/tplink/EAPController/properties/omada.properties || true)

  # check to see if we need to set the value
  if [ "${STORED_PROP_VAL}" = "" ]
  then
    echo "INFO: Skipping '${KEY}' - not present in omada.properties"
  elif [ "${STORED_PROP_VAL}" != "${END_VAL}" ]
  then
    # check to see if we are trying to bind to privileged port
    if [ "${END_VAL}" -lt "1024" ] && [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" = "1024" ]
    then
      echo "ERROR: Unable to set '${KEY}' to ${END_VAL}; 'ip_unprivileged_port_start' has not been set.  See https://github.com/mbentley/docker-omada-controller#unprivileged-ports"
      exit 1
    fi

    # update the key-value pair
    echo "INFO: Setting '${KEY}' to ${END_VAL} in omada.properties"
    sed -i "s~^${KEY}=${STORED_PROP_VAL}$~${KEY}=${END_VAL}~g" /opt/tplink/EAPController/properties/omada.properties
  else
    # values already match; nothing to change
    echo "INFO: Value of '${KEY}' already set to ${END_VAL} in omada.properties"
  fi
done

# update stored property values when different of environment defined values (works for any value)
for ELEM in MONGO_EXTERNAL EAP_MONGOD_URI
do
  # convert element to key name
  KEY="$(echo "${ELEM}" | tr '[:upper:]' '[:lower:]' | tr '_' '.')"

  # get the full key & value to store for checking later
  KEY_VALUE="$(grep "^${KEY}=" /opt/tplink/EAPController/properties/omada.properties || true)"

  # get value we want to set from the element
  END_VAL=${!ELEM}

  # get the current value from the omada.properties file
  STORED_PROP_VAL=$(grep -Po "(?<=${KEY}=)(.*)+" /opt/tplink/EAPController/properties/omada.properties || true)

  # check to see if we need to set the value; see if there is something in the key/value first
  if [ -z "${KEY_VALUE}" ]
  then
    echo "INFO: Skipping '${KEY}' - not present in omada.properties"
  elif [ "${STORED_PROP_VAL}" != "${END_VAL}" ]
  then
    # update the key-value pair
    echo "INFO: Setting '${KEY}' to ${END_VAL} in omada.properties"
    sed -i "s~^${KEY}=${STORED_PROP_VAL}$~${KEY}=${END_VAL}~g" /opt/tplink/EAPController/properties/omada.properties
  else
    # values already match; nothing to change
    echo "INFO: Value of '${KEY}' already set to ${END_VAL} in omada.properties"
  fi
done

# Import a cert from a possibly mounted secret or file at /cert
if [ -f "/cert/${SSL_KEY_NAME}" ] && [ -f "/cert/${SSL_CERT_NAME}" ]
then
  # see where the keystore directory is; check for old location first
  if [ -d /opt/tplink/EAPController/keystore ]
  then
    echo "ERROR: rootless isn't supported on versions < 5.3.1"
    exit 1
  else
    # keystore directory moved to the data directory in 5.3.1
    KEYSTORE_DIR="/opt/tplink/EAPController/data/keystore"

    # check to see if the KEYSTORE_DIR exists (it won't on upgrade)
    if [ ! -d "${KEYSTORE_DIR}" ]
    then
      echo "INFO: Creating keystore directory (${KEYSTORE_DIR})"
      mkdir "${KEYSTORE_DIR}"
      echo "INFO: Setting permissions on ${KEYSTORE_DIR}"
      chown "${USER_ID}:${GROUP_ID}" "${KEYSTORE_DIR}"
    fi
  fi

  echo "INFO: Importing cert from /cert/tls.[key|crt]"
  # delete the existing keystore
  rm -f "${KEYSTORE_DIR}/eap.keystore"

  # example certbot usage: ./certbot-auto certonly --standalone --preferred-challenges http -d mydomain.net
  openssl pkcs12 -export \
    -inkey "/cert/${SSL_KEY_NAME}" \
    -in "/cert/${SSL_CERT_NAME}" \
    -certfile "/cert/${SSL_CERT_NAME}" \
    -name eap \
    -out "${KEYSTORE_DIR}/eap.keystore" \
    -passout pass:tplink

  # set ownership/permission on keystore
  chown "${USER_ID}:${GROUP_ID}" "${KEYSTORE_DIR}/eap.keystore"
  chmod 400 "${KEYSTORE_DIR}/eap.keystore"
fi

# see if any of these files exist; if so, do not start as they are from older versions
if [ -f /opt/tplink/EAPController/data/db/tpeap.0 ] || [ -f /opt/tplink/EAPController/data/db/tpeap.1 ] || [ -f /opt/tplink/EAPController/data/db/tpeap.ns ]
then
  echo "ERROR: The data volume mounted to /opt/tplink/EAPController/data appears to have data from a previous version!"
  echo "  Follow the upgrade instructions at https://github.com/mbentley/docker-omada-controller#upgrading-to-41"
  exit 1
fi

# check to see if the CMD passed contains the text "com.tplink.omada.start.OmadaLinuxMain" which is the old classpath from 4.x
if [ "$(echo "${@}" | grep -q "com.tplink.omada.start.OmadaLinuxMain"; echo $?)" = "0" ]
then
  echo -e "\n############################"
  echo "WARN: CMD from 4.x detected!  It is likely that this container will fail to start properly with a \"Could not find or load main class com.tplink.omada.start.OmadaLinuxMain\" error!"
  echo "  See the note on old CMDs at https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#upgrade-issues for details on why and how to resolve the issue."
  echo -e "############################\n"
fi

# compare version from the image to the version stored in the persistent data (last ran version)
if [ -f "/opt/tplink/EAPController/IMAGE_OMADA_VER.txt" ]
then
  # file found; read the version that is in the image
  IMAGE_OMADA_VER="$(cat /opt/tplink/EAPController/IMAGE_OMADA_VER.txt)"
else
  echo "ERROR: Missing image version file (/opt/tplink/EAPController/IMAGE_OMADA_VER.txt); this should never happen!"
  exit 1
fi

# load LAST_RAN_OMADA_VER, if file present
if [ -f "/opt/tplink/EAPController/data/LAST_RAN_OMADA_VER.txt" ]
then
  # file found; read the version that was last recorded
  LAST_RAN_OMADA_VER="$(cat /opt/tplink/EAPController/data/LAST_RAN_OMADA_VER.txt)"
else
  # no file found; set version to 0.0.0 as we don't know the last version
  LAST_RAN_OMADA_VER="0.0.0"
fi

# make sure we are not trying to upgrade from 4.x to 5.14.32.x
LAST_RAN_MAJOR_VER="$(echo "${LAST_RAN_OMADA_VER}" | awk -F '.' '{print $1}')"
IMAGE_MAJOR_VER="$(echo "${IMAGE_OMADA_VER}" | awk -F '.' '{print $1}')"
IMAGE_MINOR_VER="$(echo "${IMAGE_OMADA_VER}" | awk -F '.' '{print $2}')"

# make sure we are not trying to upgrade from 4.x to 5.14.32.x or greater
if [ "${LAST_RAN_MAJOR_VER}" = "4" ] && [ "${IMAGE_MAJOR_VER}" -ge "5" ]
then
  # check to see if we are runnning 5.14 or greater
  if [ "${IMAGE_MAJOR_VER}" = "5" ] && [ "${IMAGE_MINOR_VER}" -ge "14" ] || [ "${IMAGE_MAJOR_VER}" -gt "5" ]
  then
    echo "ERROR: You are attempting to upgrade from 4.x to 5.14.x or greater; the upgrade code was removed in 5.14.x!"
    echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/README_v3_and_v4.md#upgrade-path for the upgrade path from 4.x to 5.x"
    exit 1
  fi
fi

# use sort to check which version is newer; should sort the newest version to the top
if [ "$(printf '%s\n' "${IMAGE_OMADA_VER}" "${LAST_RAN_OMADA_VER}" | sort -rV | head -n1)" != "${IMAGE_OMADA_VER}" ]
then
  # version in the image is didn't match newest image version; this means we are trying to start and older version
  echo "ERROR: The version from the image (${IMAGE_OMADA_VER}) is older than the last version executed (${LAST_RAN_OMADA_VER})!  Refusing to start to prevent data loss!"
  echo "  To bypass this check, remove /opt/tplink/EAPController/data/LAST_RAN_OMADA_VER.txt only if you REALLY know what you're doing!"
  exit 1
else
  echo "INFO: Version check passed; image version (${IMAGE_OMADA_VER}) >= the last version ran (${LAST_RAN_OMADA_VER}); writing image version to last ran file..."
  echo "${IMAGE_OMADA_VER}" > /opt/tplink/EAPController/data/LAST_RAN_OMADA_VER.txt
fi

# check to see if we are in a bad situation with a 32 bit userland and 64 bit kernel (fails to start MongoDB on a Raspberry Pi)
if [ "$(dpkg --print-architecture)" = "armhf" ] && [ "$(uname -m)" = "aarch64" ] && [ "${SKIP_USERLAND_KERNEL_CHECK}" = "false" ]
then
  echo "##############################################################################"
  echo "##############################################################################"
  echo "ERROR: 32 bit userspace with 64 bit kernel detected!  MongoDB will NOT start!"
  echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#mismatched-userland-and-kernel for how to fix the issue"
  echo "##############################################################################"
  echo "##############################################################################"

  exit 1
else
  echo "INFO: userland/kernel check passed"
fi

# show java version
echo -e "INFO: output of 'java -version':\n$(java -version 2>&1)\n"

# get the java version in different formats
JAVA_VERSION="$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')"
JAVA_VERSION_1="$(echo "${JAVA_VERSION}" | awk -F '.' '{print $1}')"
JAVA_VERSION_2="$(echo "${JAVA_VERSION}" | awk -F '.' '{print $2}')"

# for java 8, remove the opens argument from the CMD
case ${JAVA_VERSION_1}.${JAVA_VERSION_2} in
  1.8)
    echo "INFO: running Java 8; removing '--add-opens' option(s) from CMD (if present)..."
    # remove opens option
    NEW_CMD="${*}"
    NEW_CMD="${NEW_CMD/'--add-opens java.base/sun.security.x509=ALL-UNNAMED '/}"
    NEW_CMD="${NEW_CMD/'--add-opens java.base/sun.security.util=ALL-UNNAMED '/}"
    # shellcheck disable=SC2086
    set -- ${NEW_CMD}
    ;;
esac

# check for autobackup
if [ ! -d "/opt/tplink/EAPController/data/autobackup" ]
then
  echo
  echo "##############################################################################"
  echo "##############################################################################"
  echo "WARN: autobackup directory not found! Please configure automatic backups!"
  echo "  For instructions, see https://github.com/mbentley/docker-omada-controller#controller-backups"
  echo "##############################################################################"
  echo "##############################################################################"
  echo
  sleep 2
fi

echo "INFO: Starting Omada Controller..."

# tail the omada logs if set to true
if [ "${SHOW_SERVER_LOGS}" = "true" ]
then
  tail -F -n 0 /opt/tplink/EAPController/logs/server.log &
fi

# tail the mongodb logs if set to true
if [ "${SHOW_MONGODB_LOGS}" = "true" ]
then
  tail -F -n 0 /opt/tplink/EAPController/logs/mongod.log &
fi

# run the actual command
exec "${@}"
