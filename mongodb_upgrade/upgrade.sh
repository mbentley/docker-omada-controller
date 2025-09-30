#!/bin/bash

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

    # remove partially upgraded db
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
  echo "INFO: you can safely start back up your v5 container if you need to get your controller back up and running at this point"
  echo "INFO: if you require assistance, create a Help discussion (https://github.com/mbentley/docker-omada-controller/discussions/new?category=help) with as much information as possible"

  # exit
  exit 1
}

run_db_repair() {
  MESSAGE="${*}"

  # run repair on db
  echo -n "INFO: ${MESSAGE}..."
  # shellcheck disable=SC2086
  /tmp/mongod-${MONGO_VER} --dbpath /opt/tplink/EAPController/data/db -pidfilepath /opt/tplink/EAPController/data/mongo.pid --bind_ip 127.0.0.1 ${JOURNAL} --logpath /opt/tplink/EAPController/data/mongodb_upgrade.log --logappend --repair || abort_and_rollback
  echo "done"
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
  #run_db_repair

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
# verify the system meets the system requirements for MongoDB 8
echo -n "INFO: running hardware prerequesite checks to ensure your system supports MongoDB 8..."

# get the architecture
ARCH="$(uname -m)"

case "${ARCH}" in
  x86_64)
    # amd64 checks

    # check for AXV support
    if ! grep -qE '^flags.* avx( .*|$)' /proc/cpuinfo
    then
      echo -e "\nERROR: your system does not support AVX which is a requirement for MongoDB starting with 5.x; you will not be able to upgrade MongoDB"
      echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and your upgrade options"
      exit 1
    fi
    ;;
  aarch64|aarch64_be|armv8b|armv8l)
    # arm64 checks (list of 64 bit arm compatible names from `uname -m`: https://stackoverflow.com/a/45125525)

    # check for armv8.2-a support
    if ! grep -qE '^Features.* (fphp|dcpop|sha3|sm3|sm4|asimddp|sha512|sve)( .*|$)' /proc/cpuinfo
    then
      # failed armv8.2-a test
      echo "ERROR: your system does not support the armv8.2-a or later microarchitecture which is a requirement for MongoDB starting with 5.x; you will not be able to upgrade MongoDB"
      echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and your upgrade options"
      exit 1
    fi
    ;;
  *)
    echo "ERROR: unknown architecture (${ARCH})"
    exit 1
    ;;
esac

# prerequesite checks successful
echo "done"

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

### 3.6 to 4.0
# set variables
MONGO_VER="4.0.28"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="3.6"

# run repair
run_db_repair "starting MongoDB repair pre-upgrade to ensure consistency"

# output message
echo -e "\nINFO: executing upgrade process from MongoDB 3.6 to 8.0..."

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
MONGO_VER="6.0.25"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="5.0"

# run upgrade
version_step_upgrade


### 6.0 to 7.0
if [ "$(uname -m)" = "aarch64" ]
then
  echo -e "\nINFO: upgrading libc6 to support MongoDB 7.x & 8.x..."
  dpkg -i /libc6_2.31-0ubuntu9.18_arm64.deb
  dpkg -i /libgcc-s1_10.5.0-1ubuntu1~20.04_arm64.deb /libcrypt1_4.4.10-10ubuntu4_arm64.deb /gcc-10-base_10.5.0-1ubuntu1~20.04_arm64.deb /libc6_2.31-0ubuntu9.18_arm64.deb
  echo "done"
fi
# set variables
MONGO_VER="7.0.22"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="6.0"

# run upgrade
version_step_upgrade


### 7.0 to 8.0
# set variables
MONGO_VER="8.0.12"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="7.0"

# run upgrade
version_step_upgrade


# step upgrades finished
echo -e "\nINFO: running post-upgrade tasks..."

# set ownership
echo -n "INFO: fixing ownership of database files..."
chown -R "$(stat -c "%u:%g" /opt/tplink/EAPController/data/db)" /opt/tplink/EAPController/data
echo "done"

echo -e "\nINFO: the MongoDB backup file (mongodb-preupgrade.tar) is still in your persistent data directory in case you need to roll back but this can be removed once you have verified your controller is functioning correctly"
echo "INFO: upgrade process from MongoDB 3.6 to 8.0 was successful!"
