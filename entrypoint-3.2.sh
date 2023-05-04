#!/bin/sh

set -e

# set environment variables
export TZ
MANAGE_HTTP_PORT="${MANAGE_HTTP_PORT:-8088}"
MANAGE_HTTPS_PORT="${MANAGE_HTTPS_PORT:-8043}"
SMALL_FILES="${SMALL_FILES:-false}"
SSL_CERT_NAME="${SSL_CERT_NAME:-tls.crt}"
SSL_KEY_NAME="${SSL_KEY_NAME:-tls.key}"
TZ="${TZ:-Etc/UTC}"
PUID="${PUID:-508}"
PGID="${PGID:-508}"
SKIP_USERLAND_KERNEL_CHECK="${SKIP_USERLAND_KERNEL_CHECK:-false}"

# validate user/group exist with correct UID/GID
echo "INFO: Validating user/group (omada:omada) exists with correct UID/GID (${PUID}:${PGID})"

# check to see if group exists; if not, create it
if grep -q -E "^omada:" /etc/group > /dev/null 2>&1
then
  # exiting group found; also make sure the omada user matches the GID
  echo "INFO: Group (omada) exists; skipping creation"
  EXISTING_GID="$(id -g omada)"
  if [ "${EXISTING_GID}" != "${PGID}" ]
  then
    echo "ERROR: Group (omada) has an unexpected GID; was expecting '${PGID}' but found '${EXISTING_GID}'!"
    exit 1
  fi
else
  # make sure the group doesn't already exist with a different name
  if awk -F ':' '{print $3}' /etc/group | grep -q "^${PGID}$"
  then
    # group ID exists but has a different group name
    EXISTING_GROUP="$(grep ":${PGID}:" /etc/group | awk -F ':' '{print $1}')"
    echo "INFO: Group (omada) already exists with a different name; renaming '${EXISTING_GROUP}' to 'omada'"
    groupmod -n omada "${EXISTING_GROUP}"
  else
    # create the group
    echo "INFO: Group (omada) doesn't exist; creating"
    groupadd -g "${PGID}" omada
  fi
fi

# check to see if user exists; if not, create it
if id -u omada > /dev/null 2>&1
then
  # exiting user found; also make sure the omada user matches the UID
  echo "INFO: User (omada) exists; skipping creation"
  EXISTING_UID="$(id -u omada)"
  if [ "${EXISTING_UID}" != "${PUID}" ]
  then
    echo "ERROR: User (omada) has an unexpected UID; was expecting '${PUID}' but found '${EXISTING_UID}'!"
    exit 1
  fi
else
  # make sure the user doesn't already exist with a different name
  if awk -F ':' '{print $3}' /etc/passwd | grep -q "^${PUID}$"
  then
    # user ID exists but has a different user name
    EXISTING_USER="$(grep ":${PUID}:" /etc/passwd | awk -F ':' '{print $1}')"
    echo "INFO: User (omada) already exists with a different name; renaming '${EXISTING_USER}' to 'omada'"
    usermod -g "${PGID}" -d /opt/tplink/EAPController/work -l omada -s /bin/sh -c "" "${EXISTING_USER}"
  else
    # create the user
    echo "INFO: User (omada) doesn't exist; creating"
    useradd -u "${PUID}" -g "${PGID}" -d /opt/tplink/EAPController/work -s /bin/sh -c "" omada
  fi
fi

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# append smallfiles if set to true
if [ "${SMALL_FILES}" = "true" ]
then
  echo "INFO: Enabling smallfiles"
  # shellcheck disable=SC2016
  sed -i 's#^eap.mongod.args=--port ${eap.mongod.port} --dbpath "${eap.mongod.db}" -pidfilepath "${eap.mongod.pid.path}" --logappend --logpath "${eap.home}/logs/mongod.log" --nohttpinterface --bind_ip 127.0.0.1#eap.mongod.args=--smallfiles --port ${eap.mongod.port} --dbpath "${eap.mongod.db}" -pidfilepath "${eap.mongod.pid.path}" --logappend --logpath "${eap.home}/logs/mongod.log" --nohttpinterface --bind_ip 127.0.0.1#' /opt/tplink/EAPController/properties/mongodb.properties
fi

set_port_property() {
  # check to see if we are trying to bind to privileged port
  if [ "${3}" -lt "1024" ] && [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" = "1024" ]
  then
    echo "ERROR: Unable to set '${1}' to ${3}; 'ip_unprivileged_port_start' has not been set.  See https://github.com/mbentley/docker-omada-controller#unprivileged-ports"
    exit 1
  fi

  echo "INFO: Setting '${1}' to ${3} in jetty.properties"
  sed -i "s/^${1}=${2}/${1}=${3}/g" /opt/tplink/EAPController/properties/jetty.properties
}

# replace MANAGE_HTTP_PORT if not the default
if [ "${MANAGE_HTTP_PORT}" != "8088" ]
then
  set_port_property http.connector.port 8088 "${MANAGE_HTTP_PORT}"
fi

# replace MANAGE_HTTPS_PORT if not the default
if [ "${MANAGE_HTTPS_PORT}" != "8043" ]
then
  set_port_property https.connector.port 8043 "${MANAGE_HTTPS_PORT}"
fi

# make sure permissions are set appropriately on each directory
for DIR in data logs work
do
  OWNER="$(stat -c '%u' /opt/tplink/EAPController/${DIR})"
  GROUP="$(stat -c '%g' /opt/tplink/EAPController/${DIR})"

  if [ "${OWNER}" != "${PUID}" ] || [ "${GROUP}" != "${PGID}" ]
  then
    # notify user that uid:gid are not correct and fix them
    echo "WARN: ownership not set correctly on '/opt/tplink/EAPController/${DIR}'; setting correct ownership (omada:omada)"
    chown -R omada:omada "/opt/tplink/EAPController/${DIR}"
  fi
done

# validate permissions on /tmp
TMP_PERMISSIONS="$(stat -c '%a' /tmp)"
if [ "${TMP_PERMISSIONS}" != "1777" ]
then
  echo "WARN: permissions are not set correctly on '/tmp' (${TMP_PERMISSIONS}); setting correct permissions (1777)"
  chmod -v 1777 /tmp
fi

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown omada:omada /opt/tplink/EAPController/data/db
  echo "done"
fi

# Import a cert from a possibly mounted secret or file at /cert
if [ -f "/cert/${SSL_KEY_NAME}" ] && [ -f "/cert/${SSL_CERT_NAME}" ]
then
  echo "INFO: Importing cert from /cert/tls.[key|crt]"
  # delete the existing keystore
  rm /opt/tplink/EAPController/keystore/eap.keystore

  # example certbot usage: ./certbot-auto certonly --standalone --preferred-challenges http -d mydomain.net
  openssl pkcs12 -export \
    -inkey "/cert/${SSL_KEY_NAME}" \
    -in "/cert/${SSL_CERT_NAME}" \
    -certfile "/cert/${SSL_CERT_NAME}" \
    -name eap \
    -out /opt/tplink/EAPController/keystore/eap.keystore \
    -passout pass:tplink

  # set ownership/permission on keystore
  chown omada:omada /opt/tplink/EAPController/keystore/eap.keystore
  chmod 400 /opt/tplink/EAPController/keystore/eap.keystore
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

echo "INFO: Starting Omada Controller as user omada"
exec gosu omada "${@}"
