#!/bin/sh

set -e

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"
SMALL_FILES="${SMALL_FILES:-false}"
SSL_CERT_NAME="${SSL_CERT_NAME:-tls.crt}"
SSL_KEY_NAME="${SSL_KEY_NAME:-tls.key}"

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# append smallfiles if set to true
if [ "${SMALL_FILES}" = "true" ]
then
  echo "INFO: Enabling smallfiles"
  # shellcheck disable=SC2016
  sed -i 's#^eap.mongod.args=--port ${eap.mongod.port} --dbpath "${eap.mongod.db}" -pidfilepath "${eap.mongod.pid.path}" --logappend --logpath "${eap.home}/logs/mongod.log" --nohttpinterface --bind_ip 127.0.0.1#eap.mongod.args=--smallfiles --port ${eap.mongod.port} --dbpath "${eap.mongod.db}" -pidfilepath "${eap.mongod.pid.path}" --logappend --logpath "${eap.home}/logs/mongod.log" --nohttpinterface --bind_ip 127.0.0.1#' /opt/tplink/EAPController/properties/mongodb.properties
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

# validate permissions on /tmp
TMP_PERMISSIONS="$(stat -c '%a' /tmp)"
if [ "${TMP_PERMISSIONS}" != "1777" ]
then
  echo "WARNING: permissions are not set correctly on '/tmp' (${TMP_PERMISSIONS})!"
  echo "INFO: setting correct permissions (1777)"
  chmod -v 1777 /tmp
fi

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

echo "INFO: Starting Omada Controller as user omada"
exec gosu omada "${@}"
