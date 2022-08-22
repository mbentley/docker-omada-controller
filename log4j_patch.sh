#!/bin/bash

set -e

# set variables to get version info
if [ -n "${INSTALL_VER}" ]
then
  # INSTALL_VER was not empty
  OMADA_MAJOR_MINOR_VER="${INSTALL_VER}"  # output example: 5.5
else
  # INSTALL_VER was empty
  echo "ERROR: INSTALL_VER value is empty! This should be passed to the build using '--build-arg INSTALL_VER=5.5'"
  exit 1
fi

main() {
  # check the version of the controller
  case "${OMADA_MAJOR_MINOR_VER}" in
    3.0|3.1|4.1|4.2|4.3)
      # this version needs log4j patched (as detected using grype)
      patch_log4j
      ;;
    *)
      # all other versions do not
      echo "INFO: log4j patching not required for ${OMADA_MAJOR_MINOR_VER}; skipping applying updated versions"
      exit 0
      ;;
  esac
}

patch_log4j() {
  # install jq & gnupg2
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y gnupg2 jq
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

  # download log4j tar, log4j tar's pgp signature & signature files, and signing keys
  echo "INFO: downloading log4j (${NEW_LOG4J_VERSION})"
  wget -O "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz" "https://archive.apache.org/dist/logging/log4j/${NEW_LOG4J_VERSION}/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz"
  wget -O "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" "https://archive.apache.org/dist/logging/log4j/${NEW_LOG4J_VERSION}/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512"
  wget -O "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.asc" "https://archive.apache.org/dist/logging/log4j/${NEW_LOG4J_VERSION}/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.asc"
  wget -O "/tmp/KEYS" "https://downloads.apache.org/logging/KEYS"
  echo -e "INFO: download of log4j (${NEW_LOG4J_VERSION}) complete!\n"

  # import the gpg signing keys for log4j
  echo "INFO: importing the signing keys of the log4j developers"
  gpg2 --import "/tmp/KEYS"
  echo -e "INFO: import of the signing keys of the log4j developers complete!\n"

  # validate the signature against the log4j binaries
  echo "INFO: validating signature of the downloaded log4j binaries"
  set +e
  # validate the signatures on the files
  SIGNATURE_TEST1="$(gpg2 --verify "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.asc" >/dev/null 2>&1; echo $?)"
  set -e

  # check results
  if [ "${SIGNATURE_TEST1}" = "0" ]
  then
    echo -e "INFO: signature validation of downloaded log4j binaries complete!\n"
  else
    echo -e "ERROR: signature validation of downloaded log4j binaries failed!"
    exit 1
  fi

  ## validate the archive against the sha512 file; they're inconsistent with the output so check multiple ways
  echo "INFO: validating checksum of downloaded log4j binaries"
  set +e
  # multi-line with wrapping
  SHA512SUM_TEST1="$(tr '\n' ' ' < "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" | tr -d ' ' | awk -F ':' '{ print $2 "\t" $1 }'| sha512sum -c - >/dev/null 2>&1; echo $?)"

  # standard linux formatted output
  SHA512SUM_TEST2="$(sha512sum -c "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512" >/dev/null 2>&1; echo $?)"

  # create a checksum file by appending the filename in case it is missing & check it
  (cat apache-log4j-2.17.1-bin.tar.gz.sha512; echo " apache-log4j-2.17.1-bin.tar.gz") > apache-log4j-2.17.1-bin.tar.gz.sha512_test
  SHA512SUM_TEST3="$(sha512sum -c "/tmp/apache-log4j-${NEW_LOG4J_VERSION}-bin.tar.gz.sha512_test" >/dev/null 2>&1; echo $?)"
  set -e

  # check results of the checksum verification
  if [ "${SHA512SUM_TEST1}" = "0" ] || [ "${SHA512SUM_TEST2}" = "0" ] || [ "${SHA512SUM_TEST3}" = "0" ]
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
  echo "INFO: cleaning up /tmp and removing jq & gnupg2"
  rm -rfv /tmp/apache-log4j-* /root/.gnupg
  DEBIAN_FRONTEND=noninteractive apt-get purge -y jq gnupg2
  DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
  echo -e "INFO: cleanup of /tmp and removal of jq complete!\n"

  # output complete
  echo "INFO: patching of log4j to ${NEW_LOG4J_VERSION} is complete!"
}

main "${@}"
