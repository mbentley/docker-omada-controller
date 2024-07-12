#!/bin/bash

# TODO
#   X validate no /opt/tplink/EAPController/data/db/mongod.lock exists; abort if so
#   X backup database before upgrade
#   X rollback database on failure (and update all of the places we might exit to roll back)
#   - validate no /opt/tplink/EAPController/data/mongo.pid exists; abort if so ???
#   - amd64 requirements
#     - Add AVX check (https://www.mongodb.com/docs/manual/administration/production-notes/#x86_64)
#   - arm64 requirements
#     - Check to see if the upgrade fails on arm64 if the instruction set isn't ARMv8.2-A or later (https://www.mongodb.com/docs/manual/administration/production-notes/#arm64)

catch_error() {
  echo -e "\nERROR: unexpected failure!"
  exit 1
}

abort_and_rollback() {
  echo -e "\nERROR: unexpected failure during upgrade!"

  # only output if present
  if [ -f /opt/tplink/EAPController/data/mongodb_upgrade.log ]
  then
    echo "INFO: outputting MongoDB logs (may provide hints as to what went wrong):"
    cat /opt/tplink/EAPController/data/mongodb_upgrade.log
  fi

  echo -e "\nERROR: aborting MongoDB upgrade and rolling back!"

  # check for mongod running
  MONGOD_PROC="$(pgrep mongod)"

  # if running, kill mongod
  if [ -n "${MONGOD_PROC}" ]
  then
    # kill mongod
    echo "INFO: killing mongod process..."
    kill -9 "${MONGOD_PROC}"

    # wait for mongod to be killed
    while pgrep mongod > /dev/null
    do
      sleep .25
    done
    echo "done"
  fi

  # cleanup pid file, if present
  if [ -f /opt/tplink/EAPController/data/mongo.pid ]
  then
    echo -n "INFO: cleaning up mongo.pid..."
    rm /opt/tplink/EAPController/data/mongo.pid
    echo "done"
  fi

  # make sure we actually have a backup
  if [ -f /opt/tplink/EAPController/data/mongodb-preupgrade.tar ]
  then
    echo -n "INFO: rolling back to the backup of MongoDB prior to the upgrade..."
    # roll back to the previous backup of mongodb
    cd /opt/tplink/EAPController/data || catch_error

    # remove partially migrated db
    rm -rf db

    # restore backup
    tar xf mongodb-preupgrade.tar
    echo "done"

    echo "INFO: the MongoDB backup file (mongodb-preupgrade.tar) is still in your persistent data directory in case you need it"
  else
    # this should never happen
    echo "ERROR: there was no backup file (mongodb-preupgrade.tar) present; skipping rollback!"
  fi

  # output message about full logs, if present
  if [ -f /opt/tplink/EAPController/data/mongodb_upgrade.log ]
  then
    echo "INFO: see /opt/tplink/EAPController/data/mongodb_upgrade.log for the full MongoDB logs"
  fi

  echo "INFO: successfully rolled back MongoDB using the pre-backup archive"

  # TODO: information on what to do should go here with final error

  # exit
  exit 1
}

version_step_upgrade() {
  # start upgrade
  echo -e "\nINFO: starting upgrade to ${MONGO_MAJ_MIN}..."

  # starting with 7.0, there is no journal arg
  case "${MONGO_MAJ_MIN}" in
    7.0|8.0)
      JOURNAL=""
      ;;
    *)
      JOURNAL="--journal"
      ;;
  esac

  # run repair on db to upgrade
  #/tmp/mongod-${MONGO_VER} --dbpath /opt/tplink/EAPController/data/db -pidfilepath /opt/tplink/EAPController/data/mongo.pid --bind_ip 127.0.0.1 ${JOURNAL} --logpath /opt/tplink/EAPController/data/mongodb_upgrade.log --logappend --repair || abort_and_rollback

  # start db
  echo -n "INFO: starting mongod ${MONGO_VER}..."
  /tmp/mongod-${MONGO_VER} --fork --dbpath /opt/tplink/EAPController/data/db -pidfilepath /opt/tplink/EAPController/data/mongo.pid --bind_ip 127.0.0.1 ${JOURNAL} --logpath /opt/tplink/EAPController/data/mongodb_upgrade.log || abort_and_rollback

  # make sure MongoDB is running
  while ! echo 'db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )' | /tmp/${MONGO_CLIENT} --quiet >/dev/null 2>&1
  do
    echo -n "."
    sleep 1
  done
  echo "done"

  # get current compat version
  if [ "${MONGO_CLIENT}" = "mongosh" ]
  then
    # mongosh
    CURRENT_COMPAT_VERSION="$(/tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )' | jq -r .featureCompatibilityVersion.version)"
  else
    # mongo client
    CURRENT_COMPAT_VERSION="$(echo 'db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )' | /tmp/${MONGO_CLIENT} --quiet | jq -r .featureCompatibilityVersion.version)"
  fi

  # make sure that the current compat version is correct
  if [ "${CURRENT_COMPAT_VERSION}" != "${EXPECTED_COMPAT_VERSION}" ]
  then
    echo -e "\nERROR: featureCompatibilityVersion is currently ${CURRENT_COMPAT_VERSION}; expected ${EXPECTED_COMPAT_VERSION}; aborting upgrade!"

    # abort and rollback
    abort_and_rollback
  fi

  # set compatibility version
  echo -n "INFO: setting feature compatibility version to ${MONGO_MAJ_MIN}..."
  if [ "${MONGO_CLIENT}" = "mongosh" ]
  then
    # mongosh
    case "${MONGO_MAJ_MIN}" in
      7.0|8.0)
        /tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'", confirm: true } )' >/dev/null 2>&1
      ;;
      *)
        /tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'" } )' >/dev/null 2>&1
      ;;
    esac
  else
    # mongo client
    echo 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'" } )' | /tmp/${MONGO_CLIENT} --quiet >/dev/null 2>&1
  fi
  echo "done"

  # verify new compat version
  echo -n "INFO: verifying feature compatibility version is now ${MONGO_MAJ_MIN}..."
  if [ "${MONGO_CLIENT}" = "mongosh" ]
  then
    # mongosh
    NEW_COMPAT_VERSION="$(/tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )' | jq -r .featureCompatibilityVersion.version)"
  else
    # mongo client
    NEW_COMPAT_VERSION="$(echo 'db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )' | /tmp/${MONGO_CLIENT} --quiet | jq -r .featureCompatibilityVersion.version)"
  fi

  # make sure that the new compat version is correct
  if [ "${NEW_COMPAT_VERSION}" != "${MONGO_MAJ_MIN}" ]
  then
    echo -e "\nERROR: featureCompatibilityVersion was not updated to ${MONGO_MAJ_MIN} as expected; aborting upgrade!"

    # abort and rollback
    abort_and_rollback
  else
    echo "done"
  fi

  # stop mongodb
  echo -n "INFO: stopping mongod..."
  echo 'db.adminCommand( { shutdown: 1 } )' | /tmp/${MONGO_CLIENT} --quiet >/dev/null 2>&1

  # wait for mongodb to stop
  while pgrep mongod > /dev/null
  do
    echo -n "."
    sleep 1
  done
  echo "done"

  # remove pidfile
  rm /opt/tplink/EAPController/data/mongo.pid || abort_and_rollback

  # upgrade complete
  echo "INFO: upgrade to ${MONGO_MAJ_MIN} complete!"
}

### start of full upgrade cycle
# verify no lock file exists
echo -n "INFO: running pre-flight checks on MongoDB..."

# check to see if mongod.lock exists & it is > zero bytes
if [ -f "/opt/tplink/EAPController/data/db/mongod.lock" ] && [ -s "/opt/tplink/EAPController/data/db/mongod.lock" ]
then
  # mongod.lock exists & is > zero bytes
  echo -e "\nERROR: mongod.lock exists and isn't empty! Either the MongoDB wasn't shut down cleanly or there is another process accessing the persistent data files! Unable to execute upgrade!"
  # TODO: add instructions for what to do in this case
  exit 1
fi

# check for files known to exist when MongoDB has written data
if [ ! -f "/opt/tplink/EAPController/data/db/WiredTiger" ] || [ ! -f "/opt/tplink/EAPController/data/db/storage.bson" ]
then
  # could not find WiredTiger or a storage.bson
  echo -e "\nERROR: could not find MongoDB related files in '/opt/tplink/EAPController/data/db' (did you mount 'data' into the container using the same path as you run for the controller?)"
  exit 1
fi

# pre-flight checks successful
echo "done"

# take backup before upgrade
echo -n "INFO: creating a backup (mongodb-preupgrade.tar) of MongoDB pre-upgrade..."
cd /opt/tplink/EAPController/data || catch_error
tar cf mongodb-preupgrade.tar db

# make sure the backup file is a valid tar
if tar tf mongodb-preupgrade.tar >/dev/null 2>&1
then
  # successfully listed the files
  echo "done"
else
  # failed to list contents of tar
  echo -e "\nERROR: failed to create a backup of MongoDB; aborting upgrade!"
  exit 1
fi

# output message
echo -e "\nINFO: executing upgrade process from MongoDB 3.6 to 7.0..."

### 3.6 to 4.0
# set variables
MONGO_VER="4.0.28"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="3.6"

# run upgrade
version_step_upgrade


### 4.0 to 4.2
### upgrade to 4.2
if [ "$(uname -m)" = "aarch64" ]
then
  echo -e "\nINFO: upgrading from libcurl3 to libcurl4..."
  dpkg -i /libcurl4_7.58.0-2ubuntu3.24_arm64.deb
  echo "done"
fi

# set variables
MONGO_VER="4.2.23"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.0"

# run upgrade
version_step_upgrade


### 4.2 to 4.4
# set variables
MONGO_VER="4.4.18"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.2"

# run upgrade
version_step_upgrade


### 4.4 to 5.0
# set variables
MONGO_VER="5.0.31"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.4"

# run upgrade
version_step_upgrade


### 5.0 to 6.0
# set variables
MONGO_VER="6.0.20"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="5.0"

# run upgrade
version_step_upgrade


### 6.0 to 7.0
# set variables
MONGO_VER="7.0.16"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="6.0"

# run upgrade
version_step_upgrade


### 7.0 to 8.0
# set variables
MONGO_VER="8.0.4"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="7.0"

# run upgrade
version_step_upgrade


# step upgrades finished
echo -e "\nINFO: running post-upgrade tasks..."

# set ownership
echo -n "INFO: fixing ownership of database files..."
chown -R "$(stat -c "%u:%g" /opt/tplink/EAPController/data)" /opt/tplink/EAPController/data
echo "done"

echo -e "\nINFO: the MongoDB backup file (mongodb-preupgrade.tar) is still in your persistent data directory in case you need to roll back but this can be removed once you have verified your controller is functioning correctly"
echo "INFO: upgrade process from MongoDB 3.6 to 8.0 was successful!"
