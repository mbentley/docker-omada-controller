#!/bin/bash

set -e

# omada controller entrypoint script for versions 5.x and 6.x

# check if rootless; run alternate entrypoint
if [ "${ROOTLESS}" = "true" ]
then
  echo "INFO: ROOTLESS=true; switching to rootless entrypoint..."
  exec /entrypoint-rootless.sh "${@}"
fi

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"
SMALL_FILES="${SMALL_FILES:-false}"

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
PORT_DEVICE_MONITOR="${PORT_DEVICE_MONITOR:-29817}"
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
TLS_1_11_ENABLED="${TLS_1_11_ENABLED:-false}"
PUID="${PUID:-508}"
PGID="${PGID:-508}"
PUSERNAME="${PUSERNAME:-omada}"
PGROUP="${PGROUP:-omada}"
SKIP_USERLAND_KERNEL_CHECK="${SKIP_USERLAND_KERNEL_CHECK:-false}"

# validate user/group exist with correct UID/GID
echo "INFO: Validating user/group (${PUSERNAME}:${PGROUP}) exists with correct UID/GID (${PUID}:${PGID})"

# check to see if group exists; if not, create it
if grep -q -E "^${PGROUP}:" /etc/group > /dev/null 2>&1
then
  # existing group found; also make sure the omada group matches the GID
  echo "INFO: Group (${PGROUP}) exists; skipping creation"
  EXISTING_GID="$(getent group "${PGROUP}" | cut -d: -f3)"
  if [ "${EXISTING_GID}" != "${PGID}" ]
  then
    echo "ERROR: Group (${PGROUP}) has an unexpected GID; was expecting '${PGID}' but found '${EXISTING_GID}'!"
    exit 1
  fi
else
  # make sure the group doesn't already exist with a different name
  if awk -F ':' '{print $3}' /etc/group | grep -q "^${PGID}$"
  then
    # group ID exists but has a different group name
    EXISTING_GROUP="$(grep ":${PGID}:" /etc/group | awk -F ':' '{print $1}')"
    echo "INFO: Group (${PGROUP}) already exists with a different name; renaming '${EXISTING_GROUP}' to '${PGROUP}'"
    groupmod -n "${PGROUP}" "${EXISTING_GROUP}"
  else
    # create the group
    echo "INFO: Group (${PGROUP}) doesn't exist; creating"
    groupadd -g "${PGID}" "${PGROUP}"
  fi
fi

# check to see if user exists; if not, create it
if id -u "${PUSERNAME}" > /dev/null 2>&1
then
  # exiting user found; also make sure the omada user matches the UID
  echo "INFO: User (${PUSERNAME}) exists; skipping creation"
  EXISTING_UID="$(id -u "${PUSERNAME}")"
  if [ "${EXISTING_UID}" != "${PUID}" ]
  then
    echo "ERROR: User (${PUSERNAME}) has an unexpected UID; was expecting '${PUID}' but found '${EXISTING_UID}'!"
    exit 1
  fi
else
  # make sure the user doesn't already exist with a different name
  if awk -F ':' '{print $3}' /etc/passwd | grep -q "^${PUID}$"
  then
    # user ID exists but has a different user name
    EXISTING_USER="$(grep ":${PUID}:" /etc/passwd | awk -F ':' '{print $1}')"
    echo "INFO: User (${PUSERNAME}) already exists with a different name; renaming '${EXISTING_USER}' to '${PUSERNAME}'"
    usermod -g "${PGID}" -d /opt/tplink/EAPController/data -l "${PUSERNAME}" -s /bin/sh -c "" "${EXISTING_USER}"
  else
    # create the user
    echo "INFO: User (${PUSERNAME}) doesn't exist; creating"
    useradd -u "${PUID}" -g "${PGID}" -d /opt/tplink/EAPController/data -s /bin/sh -c "" "${PUSERNAME}"
  fi
fi

# check if properties file exists; create it if it is missing
DEFAULT_FILES="/opt/tplink/EAPController/properties.defaults/*"
for FILE in ${DEFAULT_FILES}
do
  BASENAME=$(basename "${FILE}")
  if [ ! -f "/opt/tplink/EAPController/properties/${BASENAME}" ]
  then
    echo "INFO: Properties file '${BASENAME}' missing, restoring default file..."
    cp "${FILE}" "/opt/tplink/EAPController/properties/${BASENAME}"
    chown "${PUSERNAME}:${PGROUP}" "/opt/tplink/EAPController/properties/${BASENAME}"
  fi
done

# make sure that the html directory exists
if [ ! -d "/opt/tplink/EAPController/data/html" ] && [ -f "/opt/tplink/EAPController/data-html.tar.gz" ]
then
  # missing directory; extract from original
  echo "INFO: Report HTML directory missing; extracting backup to '/opt/tplink/EAPController/data/html'"
  tar zxvf /opt/tplink/EAPController/data-html.tar.gz -C /opt/tplink/EAPController/data
  chown -R "${PUSERNAME}:${PGROUP}" /opt/tplink/EAPController/data/html
fi

# make sure that the pdf directory exists
if [ ! -d "/opt/tplink/EAPController/data/pdf" ]
then
  # missing directory; extract from original
  echo "INFO: Report PDF directory missing; creating '/opt/tplink/EAPController/data/pdf'"
  mkdir /opt/tplink/EAPController/data/pdf
  chown -R "${PUSERNAME}:${PGROUP}" /opt/tplink/EAPController/data/pdf
fi

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown "${PUSERNAME}:${PGROUP}" /opt/tplink/EAPController/data/db
  echo "done"
fi

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# append smallfiles if set to true
if [ "${SMALL_FILES}" = "true" ]
then
  echo "WARN: smallfiles was passed but is not supported in >= 4.1 with the WiredTiger engine in use by MongoDB"
  echo "INFO: Skipping setting smallfiles option"
fi

# update stored ports when different of enviroment defined ports (works for numbers only)
for ELEM in MANAGE_HTTP_PORT MANAGE_HTTPS_PORT PORTAL_HTTP_PORT PORTAL_HTTPS_PORT PORT_ADOPT_V1 PORT_APP_DISCOVERY PORT_UPGRADE_V1 PORT_MANAGER_V1 PORT_MANAGER_V2 PORT_DISCOVERY PORT_TRANSFER_V2 PORT_RTTY PORT_DEVICE_MONITOR
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

# make sure permissions are set appropriately on each directory
for DIR in data logs properties
do
  OWNER="$(stat -c '%u' /opt/tplink/EAPController/${DIR})"
  GROUP="$(stat -c '%g' /opt/tplink/EAPController/${DIR})"

  if [ "${OWNER}" != "${PUID}" ] || [ "${GROUP}" != "${PGID}" ]
  then
    # notify user that uid:gid are not correct and fix them
    echo "WARN: Ownership not set correctly on '/opt/tplink/EAPController/${DIR}'; setting correct ownership (${PUSERNAME}:${PGROUP})"
    chown -R "${PUSERNAME}:${PGROUP}" "/opt/tplink/EAPController/${DIR}"
  fi
done

# validate permissions on /tmp
TMP_PERMISSIONS="$(stat -c '%a' /tmp)"
if [ "${TMP_PERMISSIONS}" != "1777" ]
then
  echo "WARN: Permissions are not set correctly on '/tmp' (${TMP_PERMISSIONS}); setting correct permissions (1777)"
  chmod -v 1777 /tmp
fi

# Import a cert from a possibly mounted secret or file at /cert
if [ -f "/cert/${SSL_KEY_NAME}" ] && [ -f "/cert/${SSL_CERT_NAME}" ]
then
  # see where the keystore directory is; check for old location first
  if [ -d /opt/tplink/EAPController/keystore ]
  then
    # keystore in the parent folder before 5.3.1
    KEYSTORE_DIR="/opt/tplink/EAPController/keystore"
  else
    # keystore directory moved to the data directory in 5.3.1
    KEYSTORE_DIR="/opt/tplink/EAPController/data/keystore"

    # check to see if the KEYSTORE_DIR exists (it won't on upgrade)
    if [ ! -d "${KEYSTORE_DIR}" ]
    then
      echo "INFO: Creating keystore directory (${KEYSTORE_DIR})"
      mkdir "${KEYSTORE_DIR}"
      echo "INFO: Setting permissions on ${KEYSTORE_DIR}"
      chown "${PUSERNAME}:${PGROUP}" "${KEYSTORE_DIR}"
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
  chown "${PUSERNAME}:${PGROUP}" "${KEYSTORE_DIR}/eap.keystore"
  chmod 400 "${KEYSTORE_DIR}/eap.keystore"
fi

# re-enable disabled TLS versions 1.0 & 1.1
if [ "${TLS_1_11_ENABLED}" = "true" ]
then
  echo "INFO: Re-enabling TLS 1.0 & 1.1"
  if [ -f "/etc/java-8-openjdk/security/java.security" ]
  then
    # openjdk8
    sed -i 's#^jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1,#jdk.tls.disabledAlgorithms=SSLv3,#' /etc/java-8-openjdk/security/java.security
  elif [ -f "/etc/java-17-openjdk/security/java.security" ]
  then
    # openjdk17
    sed -i 's#^jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1,#jdk.tls.disabledAlgorithms=SSLv3,#' /etc/java-17-openjdk/security/java.security
  else
    # not running openjdk8 or openjdk17
    echo "WARN: Unable to re-enable TLS 1.0 & 1.1; unable to detect openjdk version"
  fi
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

# get version strings that will be useful
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

# check to make sure we have the supported cpu features for MongoDB included with 6.x when not using an external MongoDB
if [ "${IMAGE_MAJOR_VER}" = "6" ] && [ "${MONGO_EXTERNAL}" != "true" ]
then
  # running 6.x and not using external mongodb; get cpu architecture
  ARCH="$(uname -m)"

  case "${ARCH}" in
    x86_64)
      # amd64 checks
      echo -n "INFO: running hardware prerequisite check for AVX support on ${ARCH} to ensure your system can run MongoDB 8..."

      # check for AVX support
      if ! grep -qE '^flags.* avx( .*|$)' /proc/cpuinfo
      then
        echo -e "\nERROR: your system does not support AVX which is a requirement for the v6 and above container image as it only ships with MongoDB 8"
        echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and how you can address this"
        exit 1
      fi
      ;;
    aarch64|aarch64_be|armv8b|armv8l)
      # arm64 checks (list of 64 bit arm compatible names from `uname -m`: https://stackoverflow.com/a/45125525)
      echo -n "INFO: running hardware prerequisite check for armv8.2-a support on ${ARCH} to ensure your system can run MongoDB 8..."

      # check for armv8.2-a support
      if ! grep -qE '^Features.* (fphp|dcpop|sha3|sm3|sm4|asimddp|sha512|sve)( .*|$)' /proc/cpuinfo
      then
        # failed armv8.2-a test
        echo -e "\nERROR: your system does not support the armv8.2-a or later microarchitecture which is a requirement for the v6 and above container image as it only ships with MongoDB 8"
        echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and how you can address this"
        exit 1
      fi
      ;;
    *)
      echo -e "\nERROR: unknown architecture (${ARCH})"
      exit 1
      ;;
  esac

  # prerequisite checks successful
  echo "done"
fi

# see if this is our first run or if we are using an external MongoDB
if [ "${LAST_RAN_OMADA_VER}" = "0.0.0" ]
then
  echo "INFO: skipping MongoDB data version check; first time running"
elif [ "${MONGO_EXTERNAL}" = "true" ]
then
  echo "INFO: skipping MongoDB data version check; using external MongoDB"
else
  # check to see if we are running v6 but have mongodb persistent data from an older mongodb
  if [ "${IMAGE_MAJOR_VER}" = "6" ] && [ "${LAST_RAN_MAJOR_VER}" != "6" ]
  then
    echo "INFO: Comparing your MongoDB version with the persistent data..."
    # get wiredtiger version
    WT_VERSION="$(grep -o 'WiredTiger [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' /opt/tplink/EAPController/data/db/WiredTiger.turtle | cut -d' ' -f2)"

    if [ -z "${WT_VERSION}" ]
    then
      echo "ERROR: Unable to parse the WiredTiger version!"
      exit 1
    fi

    # check if the wiredtiger version is not 11.3.0
    if [ "${WT_VERSION}" != "11.3.0" ]
    then
      echo "ERROR: Your persistent data for MongoDB is using WiredTiger ${WT_VERSION} (an older MongoDB) but this version of the image has MongoDB $(mongod --version | grep "db version" | awk -F 'n v' '{print $2}')!"
      echo "  You either need to revert back to a previous v5 tag or manually execute the MongoDB database upgrade."
      echo "  See https://github.com/mbentley/docker-omada-controller/tree/update-base-and-mongo/mongodb_upgrade#help-my-controller-stopped-working for instructions on what to do"
      exit 1
    else
      echo "INFO: Success! Your MongoDB version matches your persistent data; continuing with entrypoint startup..."
    fi
  else
    echo "INFO: Skipping MongoDB version check; image version != 6 and the last ran version != 6 (this is normal)"
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

# see if we should try to delete bcpkix-jdk15on-1.70.jar and bcprov-jdk15on-1.70.jar to workaround https://github.com/mbentley/docker-omada-controller/issues/509
if [ "${WORKAROUND_509}" = "true" ] && [ "${IMAGE_OMADA_VER}" = "5.15.6.7" ]
then
  echo "INFO: WORKAROUND_509=true; deleting files that block controller startup, if present"

  # delete files, if present
  for FILE in bcpkix-jdk15on-1.70.jar bcprov-jdk15on-1.70.jar
  do
    # see if the file is there
    if [ -f "${FILE}" ]
    then
      # found; delete it
      echo -ne "INFO: deleting '/opt/tplink/EAPController/lib/${FILE}'\nINFO: "
      rm -v "/opt/tplink/EAPController/lib/${FILE}"
    else
      # not found
      echo "INFO: '/opt/tplink/EAPController/lib/${FILE}' isn't present, skipping"
    fi
  done

  echo "INFO: WORKAROUND_509 complete!"
elif [ "${WORKAROUND_509}" = "true" ] && [ "${IMAGE_OMADA_VER}" != "5.15.6.7" ]
then
  echo "WARN: WORKAROUND_509=true; but you're not running an impacted version; skipping workaround. (You should remove this env var as it does nothing!)"
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

# inject cloudsdk JAR at the beginning of the classpath to ensure correct certificate loads first
# check if we're actually starting the Omada controller (not just running some other command)
if echo "${@}" | grep -q "com.tplink.smb.omada.starter.OmadaLinuxMain"
then
  echo "INFO: Omada Controller startup detected; proceeding with cloudsdk JAR injection"

  # find the cloudsdk JAR dynamically (version-agnostic)
  CLOUDSDK_JAR="$(find /opt/tplink/EAPController/lib -maxdepth 1 -name "cloudsdk-*.jar" | head -n 1)"

  if [ -n "${CLOUDSDK_JAR}" ]
  then
    echo "INFO: Found cloudsdk JAR: ${CLOUDSDK_JAR}"

    # parse CMD arguments to find and modify the -cp parameter
    NEW_ARGS=()
    NEXT_IS_CP=false

    for ARG in "${@}"
    do
      if [ "${NEXT_IS_CP}" = "true" ]
      then
        # this is the classpath value; inject cloudsdk JAR at the beginning
        NEW_ARGS+=("${CLOUDSDK_JAR}:${ARG}")
        NEXT_IS_CP=false
        echo "INFO: Modified classpath to: ${CLOUDSDK_JAR}:${ARG}"
      elif [ "${ARG}" = "-cp" ] || [ "${ARG}" = "-classpath" ]
      then
        # found the classpath flag
        NEW_ARGS+=("${ARG}")
        NEXT_IS_CP=true
      else
        # regular argument
        NEW_ARGS+=("${ARG}")
      fi
    done

    # replace the original arguments with modified ones
    set -- "${NEW_ARGS[@]}"
  else
    echo "WARN: cloudsdk JAR not found; classpath injection skipped (cloud connection may fail!)"
  fi
else
  echo "INFO: Not starting Omada Controller; skipping cloudsdk JAR injection"
fi

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

echo "INFO: Starting Omada Controller as user ${PUSERNAME}"

# tail the omada logs if set to true
if [ "${SHOW_SERVER_LOGS}" = "true" ]
then
  gosu "${PUSERNAME}" tail -F -n 0 /opt/tplink/EAPController/logs/server.log &
fi

# tail the mongodb logs if set to true
if [ "${SHOW_MONGODB_LOGS}" = "true" ]
then
  gosu "${PUSERNAME}" tail -F -n 0 /opt/tplink/EAPController/logs/mongod.log &
fi

# run the actual command as the omada user
exec gosu "${PUSERNAME}" "${@}"
