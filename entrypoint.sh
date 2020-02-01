#!/bin/sh

set -e

# notify user of time zone
echo "INFO: Time zone set to '${TZ}'"

# make sure permissions are set appropriately on each directory
for DIR in data work logs
do
  if [ "$(stat -c '%u' /opt/tplink/EAPController/${DIR})" != "508" ]
  then
    echo "ERROR: ownership not set appropriate on /opt/tplink/EAPController/${DIR}"
    echo "  Hint: ownership should be set to 508:508; see https://github.com/mbentley/docker-omada-controller#persistent-data-and-permissions"
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
