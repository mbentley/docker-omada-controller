#!/bin/bash

catch_error() {
  echo "ERROR: Unexpected failure!"
  exit 1
}

upgrade_mongodb() {
  # start upgrade
  echo -e "\nINFO: starting upgrade to ${MONGO_MAJ_MIN}..."

  # starting with 7.0, there is no journal arg
  if [ "${MONGO_MAJ_MIN}" != "7.0" ]
  then
    JOURNAL="--journal"
  else
    JOURNAL=""
  fi

  # run repair on db to upgrade
  #/tmp/mongod-${MONGO_VER} --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 ${JOURNAL} --logpath /tmp/upgrade_log.txt --logappend --repair || catch_error

  # start db
  echo -n "INFO: starting mongod ${MONGO_VER}..."
  /tmp/mongod-${MONGO_VER} --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 ${JOURNAL} --logpath /tmp/upgrade_log.txt --logappend &

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
    exit 1
  fi

  # set compatibility version
  echo -n "INFO: setting feature compatibility version to ${MONGO_MAJ_MIN}..."
  if [ "${MONGO_CLIENT}" = "mongosh" ]
  then
    # mongosh
    if [ "${MONGO_MAJ_MIN}" = "7.0" ]
    then
      # 7.0
      /tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'", confirm: true } )' >/dev/null 2>&1
    else
      # not 7.0
      /tmp/${MONGO_CLIENT} --quiet --json --eval 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'" } )' >/dev/null 2>&1
    fi
  else
    # mongo client
    echo 'db.adminCommand( { setFeatureCompatibilityVersion: "'"${MONGO_MAJ_MIN}"'" } )' | /tmp/${MONGO_CLIENT} --quiet >/dev/null 2>&1
  fi
  echo "done"

  # verify new compat version
  echo -n "INFO: verifying feature compatibility version has been updated to ${MONGO_MAJ_MIN}..."
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
    exit 1
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
  rm ../data/mongo.pid || catch_error

  # upgrade complete
  echo -e "INFO: upgrade to ${MONGO_MAJ_MIN} complete!\n"
}

# output message
echo -e "INFO: executing upgrade process from MongoDB 3.6 to 7.0...\n"

### 3.6 to 4.0
# set variables
MONGO_VER="4.0.28"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="3.6"

# run upgrade
upgrade_mongodb


### 4.0 to 4.2
### upgrade to 4.2
if [ "$(uname -m)" = "aarch64" ]
then
  echo "INFO: upgrading from libcurl3 to libcurl4"
  dpkg -i /libcurl4_7.58.0-2ubuntu3.24_arm64.deb
fi

# set variables
MONGO_VER="4.2.23"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.0"

# run upgrade
upgrade_mongodb


### 4.2 to 4.4
# set variables
MONGO_VER="4.4.18"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.2"

# run upgrade
upgrade_mongodb


### 4.4 to 5.0
# set variables
MONGO_VER="5.0.27"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongo-${MONGO_VER}"
EXPECTED_COMPAT_VERSION="4.4"

# run upgrade
upgrade_mongodb


### 5.0 to 6.0
# set variables
MONGO_VER="6.0.16"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="5.0"

# run upgrade
upgrade_mongodb


### 6.0 to 7.0
# set variables
MONGO_VER="7.0.12"
MONGO_MAJ_MIN="$(echo "${MONGO_VER}" | awk -F '.' '{print $1"."$2}')"
MONGO_CLIENT="mongosh"
EXPECTED_COMPAT_VERSION="6.0"

# run upgrade
upgrade_mongodb

# set ownership
echo -ne "\nINFO: Fixing ownership of database files..."
chown -R "$(stat -c "%u:%g" ../data)" ../data
echo "done"

echo -e "\n\nINFO: upgrade process from MongoDB 3.6 to 7.0 was successful!"
