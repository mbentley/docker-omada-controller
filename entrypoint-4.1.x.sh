#!/bin/sh

set -e

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"
SMALL_FILES="${SMALL_FILES:-false}"

# set default time zone and notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# append smallfiles if set to true
if [ "${SMALL_FILES}" = "true" ]
then
  echo "WARNING: smallfiles was passed but is not supported in >= 4.1 with the WiredTiger engine in use by MongoDB"
  echo "INFO: skipping setting smallfiles option"
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
if [ -f /cert/tls.key ] && [ -f /cert/tls.crt ]
then
  echo "INFO: Importing Cert from /cert/tls.[key|crt]"
  # example certbot usage: ./certbot-auto certonly --standalone --preferred-challenges http -d mydomain.net
  openssl pkcs12 -export \
    -inkey /cert/tls.key \
    -in /cert/tls.crt \
    -certfile /cert/tls.crt \
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

# tail the logs in the background so they output to STDOUT
gosu omada tail -F -n 0 /opt/tplink/EAPController/logs/server.log &
gosu omada tail -F -n 0 /opt/tplink/EAPController/logs/mongod.log &

# run the actual command as the omada user
exec gosu omada "${@}"
