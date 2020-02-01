#!/bin/sh

set -e

# set default time zone and notify user of time zone
export TZ
TZ="${TZ:-Etc/UTC}"
echo "INFO: Time zone set to '${TZ}'"

# make sure permissions are set appropriately on each directory
for DIR in data work logs
do
  OWNER="$(stat -c '%u' /opt/tplink/EAPController/${DIR}))"
  GROUP="$(stat -c '%g' /opt/tplink/EAPController/${DIR}))"

  if [ "${OWNER}" != "508" ] || [ "${GROUP}" != "508" ]
  then
    echo "ERROR: owner or group (${OWNER}:${GROUP}) not set correctly on /opt/tplink/EAPController/${DIR}"
    echo "  Hint: owner and group should be set to 508:508; see https://github.com/mbentley/docker-omada-controller#persistent-data-and-permissions"
    exit 1
  fi
done

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  echo "INFO: Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  echo "done"
fi

echo "INFO: Starting Omada Controller"
exec "${@}"
