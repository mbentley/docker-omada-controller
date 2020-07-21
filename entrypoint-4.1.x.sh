#!/bin/sh

set -e

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"
SMALL_FILES="${SMALL_FILES:-false}"
MANAGE_HTTP_PORT="${MANAGE_HTTP_PORT:-8088}"
MANAGE_HTTPS_PORT="${MANAGE_HTTPS_PORT:-8043}"
PORTAL_HTTP_PORT="${PORTAL_HTTP_PORT:-8088}"
PORTAL_HTTPS_PORT="${PORTAL_HTTPS_PORT:-8843}"
SHOW_SERVER_LOGS="${SHOW_SERVER_LOGS:-true}"
SHOW_MONGODB_LOGS="${SHOW_MONGODB_LOGS:-false}"
SSL_CERT_NAME="${SSL_CERT_NAME:-tls.crt}"
SSL_KEY_NAME="${SSL_KEY_NAME:-tls.key}"

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# append smallfiles if set to true
if [ "${SMALL_FILES}" = "true" ]
then
  echo "WARNING: smallfiles was passed but is not supported in >= 4.1 with the WiredTiger engine in use by MongoDB"
  echo "INFO: skipping setting smallfiles option"
fi

set_port_property() {
  if [ -f "/opt/tplink/EAPController/data/db/storage.bson" ]
  then
    echo "WARNING: Unable to change '${1}' to ${3} after initial run; change the ports via the web UI"
  else

    # check to see if we are trying to bind to privileged port
    if [ "${3}" -lt "1024" ] && [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" = "1024" ]
    then
      echo "ERROR: Unable to set '${1}' to $3; 'ip_unprivileged_port_start' has not been set.  See https://github.com/mbentley/docker-omada-controller#unprivileged-ports"
      exit 1
    fi

    echo "INFO: Setting '${1}' to ${3}"
    sed -i "s/^${1}=${2}$/${1}=${3}/g" /opt/tplink/EAPController/properties/omada.properties
  fi
}

# replace MANAGE_HTTP_PORT if not the default
if [ "${MANAGE_HTTP_PORT}" != "8088" ]
then
  set_port_property manage.http.port 8088 "${MANAGE_HTTP_PORT}"
fi

# replace MANAGE_HTTPS_PORT if not the default
if [ "${MANAGE_HTTPS_PORT}" != "8043" ]
then
  set_port_property manage.https.port 8043 "${MANAGE_HTTPS_PORT}"
fi

# replace PORTAL_HTTP_PORT if not the default
if [ "${PORTAL_HTTP_PORT}" != "8088" ]
then
  set_port_property portal.http.port 8088 "${PORTAL_HTTP_PORT}"
fi

# replace PORTAL_HTTPS_PORT if not the default
if [ "${PORTAL_HTTPS_PORT}" != "8843" ]
then
  set_port_property portal.https.port 8843 "${PORTAL_HTTPS_PORT}"
fi

# make sure permissions are set appropriately on each directory
for DIR in data work logs
do
  OWNER="$(stat -c '%u' /opt/tplink/EAPController/${DIR})"
  GROUP="$(stat -c '%g' /opt/tplink/EAPController/${DIR})"

  if [ "${OWNER}" != "508" ] || [ "${GROUP}" != "508" ]
  then
    # notify user that uid:gid are not correct and fix them
    echo "WARNING: owner or group (${OWNER}:${GROUP}) not set correctly on '/opt/tplink/EAPController/${DIR}'"
    echo "INFO: setting correct permissions"
    chown -R 508:508 "/opt/tplink/EAPController/${DIR}"
  fi
done

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown 508:508 /opt/tplink/EAPController/data/db
  echo "done"
fi

# Import a cert from a possibly mounted secret or file at /cert
if [ -f "/cert/${SSL_KEY_NAME}" ] && [ -f "/cert/${SSL_CERT_NAME}" ]
then
  echo "INFO: Importing Cert from /cert/tls.[key|crt]"
  # example certbot usage: ./certbot-auto certonly --standalone --preferred-challenges http -d mydomain.net
  openssl pkcs12 -export \
    -inkey "/cert/${SSL_KEY_NAME}" \
    -in "/cert/${SSL_CERT_NAME}" \
    -certfile "/cert/${SSL_CERT_NAME}" \
    -name eap \
    -out /opt/tplink/EAPController/keystore/cert.p12 \
    -passout pass:tplink

  # delete the existing keystore
  rm /opt/tplink/EAPController/keystore/eap.keystore
  keytool -importkeystore \
    -deststorepass tplink \
    -destkeystore /opt/tplink/EAPController/keystore/eap.keystore \
    -srckeystore /opt/tplink/EAPController/keystore/cert.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass tplink
fi

# see if any of these files exist; if so, do not start as they are from older versions
if [ -f /opt/tplink/EAPController/data/db/tpeap.0 ] || [ -f /opt/tplink/EAPController/data/db/tpeap.1 ] || [ -f /opt/tplink/EAPController/data/db/tpeap.ns ]
then
  echo "ERROR: the data volume mounted to /opt/tplink/EAPController/data appears to have data from a previous version!"
  echo "  Follow the upgrade instructions at https://github.com/mbentley/docker-omada-controller#upgrading-to-41"
  exit 1
fi

echo "INFO: Starting Omada Controller as user omada"

# tail the omada logs if set to true
if [ "${SHOW_SERVER_LOGS}" = "true" ]
then
  gosu omada tail -F -n 0 /opt/tplink/EAPController/logs/server.log &
fi

# tail the mongodb logs if set to true
if [ "${SHOW_MONGODB_LOGS}" = "true" ]
then
  gosu omada tail -F -n 0 /opt/tplink/EAPController/logs/mongod.log &
fi

# run the actual command as the omada user
exec gosu omada "${@}"
