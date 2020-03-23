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

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown 508:508 /opt/tplink/EAPController/data/db
  echo "done"
fi

echo "INFO: Starting Omada Controller as user omada"
exec gosu omada "${@}"
