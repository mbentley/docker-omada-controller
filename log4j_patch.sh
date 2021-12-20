#!/bin/bash

set -e

# install jq
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y jq
rm -rf /var/lib/apt/lists/*

# get the new log4j version from the github tags
NEW_LOG4J_VERSION="$(wget -q -O - "https://api.github.com/repos/apache/logging-log4j2/tags?per_page=50" | jq -r '.[] | select(.name | startswith("rel/2.")) | .name' | sort --version-sort -r | head -n 1 | awk -F '/' '{print $2}')"
OMADA_LIB_PATH="/opt/tplink/EAPController/lib"

# determine existing filenames of binaries to replace
LOG4J_API="$(ls "${OMADA_LIB_PATH}"/log4j-api-*)"
LOG4J_CORE="$(ls "${OMADA_LIB_PATH}"/log4j-core-*)"
LOG4J_SLF4J_IMPL="$(ls "${OMADA_LIB_PATH}"/log4j-slf4j-impl-*)"

# output start
echo -e "INFO: patching log4j to ${NEW_LOG4J_VERSION}\n"

# cd to tmp
cd /tmp

# download log4j tar & log4j tar's pgp signature file
echo "INFO: downloading log4j (${NEW_LOG4J_VERSION})"
wget -O "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz" "https://archive.apache.org/dist/logging/log4j/${NEW_LOG4J_VERSION}/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz"
wget -O "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" "https://archive.apache.org/dist/logging/log4j/${NEW_LOG4J_VERSION}/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512"
echo -e "INFO: download of log4j (${NEW_LOG4J_VERSION}) complete!\n"

# validate the archive against the sha
echo "INFO: validating checksum of downloaded log4j binaries"
set +e
# check sha512sum response; they're inconsistent with the output so check both ways
SHA512SUM_TEST1="$(tr '\n' ' ' < "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" | tr -d ' ' | awk -F ':' '{ print $2 "\t" $1 }'| sha512sum -c - >/dev/null 2>&1; echo $?)"
SHA512SUM_TEST2="$(sha512sum -c "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" >/dev/null 2>&1; echo $?)"
set -e

# check results
if [ "${SHA512SUM_TEST1}" = "0" ] || [ "${SHA512SUM_TEST2}" = "0" ]
then
  echo -e "INFO: checksum validation of downloaded log4j binaries complete!\n"
else
  echo -e "ERROR: checksum validation of downloaded log4j binaries failed!"
  exit 1
fi

# extract just the files we need
echo "INFO: extracting specific jar files required to patch log4j"
tar xvf "apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz" \
  "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-api-${NEW_LOG4J_VERSION}.jar" \
  "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-core-${NEW_LOG4J_VERSION}.jar" \
  "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-slf4j-impl-${NEW_LOG4J_VERSION}.jar"
echo -e "INFO: extraction of specific jar files required to patch log4j complete!\n"

# move the files to the correct location
echo "INFO: moving extracted jar files required to patch log4j over the old jar files"
mv -v "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-api-${NEW_LOG4J_VERSION}.jar" "${LOG4J_API}"
mv -v "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-core-${NEW_LOG4J_VERSION}.jar" "${LOG4J_CORE}"
mv -v "apache-log4j-${NEW_LOG4J_VERSION}-bin/log4j-slf4j-impl-${NEW_LOG4J_VERSION}.jar" "${LOG4J_SLF4J_IMPL}"
echo -e "INFO: move of extracted jar files required to patch log4j over the old jar files complete!\n"

# set permissions on new log4j files
echo "INFO: setting ownership and permissions on patched log4j files"
chown -v root:root "${LOG4J_API}" "${LOG4J_CORE}" "${LOG4J_SLF4J_IMPL}"
chmod -v 755 "${LOG4J_API}" "${LOG4J_CORE}" "${LOG4J_SLF4J_IMPL}"
echo -e "INFO: ownership and permissions setting on patched log4j files complete!\n"

# cleanup
echo "INFO: cleaning up /tmp and removing jq"
rm -rfv /tmp/apache-log4j-*
DEBIAN_FRONTEND=noninteractive apt-get purge -y jq
echo -e "INFO: cleanup of /tmp and removal of jq complete!\n"

# output complete
echo "INFO: patching of log4j to ${NEW_LOG4J_VERSION} is complete!"
