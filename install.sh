#!/usr/bin/env bash

set -e

# omada controller dependency and package installer script for version 5.x

# set default variables
OMADA_DIR="/opt/tplink/EAPController"
ARCH="${ARCH:-}"
NO_MONGODB="${NO_MONGODB:-false}"
INSTALL_VER="${INSTALL_VER:-}"

# install wget
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends -y ca-certificates unzip wget

# for armv7l, force the creation of the ssl cert hashes (see https://stackoverflow.com/questions/70767396/docker-certificate-error-when-building-for-arm-v7-platform)
if [ "${ARCH}" = "armv7l" ]
then
  for i in /etc/ssl/certs/*.pem; do HASH=$(openssl x509 -hash -noout -in "${i}"); ln -sfv "$(basename "${i}")" "/etc/ssl/certs/${HASH}.0"; done
fi

# get URL to package based on major.minor version; for information on this url API, see https://github.com/mbentley/docker-omada-controller-url
OMADA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=${INSTALL_VER}")"

# make sure OMADA_URL isn't empty
if [ -z "${OMADA_URL}" ]
then
  echo "ERROR: ${OMADA_URL} did not return a valid URL"
  exit 1
fi

# extract required data from the OMADA_URL
OMADA_TAR="$(echo "${OMADA_URL}" | awk -F '/' '{print $NF}')"
OMADA_VER="$(echo "${OMADA_TAR}" | awk -F '_v' '{print $2}' | awk -F '_' '{print $1}')"

# try alternate way to get OMADA_VER if not found
if [ -z "${OMADA_VER}" ]
then
  echo "INFO: failed to get OMADA_VER; trying alternate method of getting OMADA_VER..."
  # get only numbers and periods; remove any beginning or trailing periods with sed (also get rid of 64 from x64 from end)
  OMADA_VER="$(echo "${OMADA_TAR//[!0-9.]/}" | sed 's/\.*$//' | sed 's/^\.*//' | sed 's/64$//')"
fi

OMADA_MAJOR_VER="$(echo "${OMADA_VER}" | awk -F '.' '{print $1}')"
OMADA_MAJOR_MINOR_VER="$(echo "${OMADA_VER}" | awk -F '.' '{print $1"."$2}')"

# make sure we were able to figure out these env vars
if [ -z "${OMADA_TAR}" ] || [ -z "${OMADA_VER}" ] || [ -z "${OMADA_MAJOR_VER}" ] || [ -z "${OMADA_MAJOR_MINOR_VER}" ]
then
  echo "ERROR: one of the following variables wasn't populated:"
  echo "  OMADA_TAR=\"${OMADA_TAR}\""
  echo "  OMADA_VER=\"${OMADA_VER}\""
  echo "  OMADA_MAJOR_VER=\"${OMADA_MAJOR_VER}\""
  echo "  OMADA_MAJOR_MINOR_VER=\"${OMADA_MAJOR_MINOR_VER}\""
  exit 1
fi

# function to exit on error w/message
die() { echo -e "$@" 2>&1; exit 1; }

echo "**** Selecting packages based on the architecture and version ****"
# common package dependencies
PKGS=(
  gosu
  net-tools
  tzdata
  wget
)

# add specific package for mongodb
case "${NO_MONGODB}" in
  true)
    # do not include mongodb
    ;;
  *)
    # include mongodb
    case "${ARCH}" in
      amd64|arm64|"")
        PKGS+=( mongodb-server-core )
        ;;
      armv7l)
        PKGS+=( mongodb )
        ;;
      *)
        die "${ARCH}: unsupported ARCH"
        ;;
    esac
    ;;
esac

# add specific package for openjdk
case "${ARCH}:${NO_MONGODB}" in
  amd64:*|arm64:*|armv7l:true|"":*)
    # use openjdk-17 for v5.4 and above; all others use openjdk-8
    case "${OMADA_MAJOR_VER}" in
      5)
        # pick specific package based on the major.minor version
        case "${OMADA_MAJOR_MINOR_VER}" in
          5.0|5.1|5.3)
            # 5.0 to 5.3 all use openjdk-8
            PKGS+=( openjdk-8-jre-headless )
            ;;
          *)
            # starting with 5.4, OpenJDK 17 is supported; we will use OpenJ9 if present or OpenJDK 17 if not
            if [ "$(. /opt/java/openjdk/release >/dev/null 2>&1; echo "${JVM_VARIANT}")" = "Openj9" ]
            then
              # we found OpenJ9; assume we want to use that
              echo "INFO: OpenJ9 was found; using that instead of OpenJDK 17!"
            else
              # OpenJ9 not found; assume we need to use OpenJDK 17
              echo "INFO: OpenJ9 was NOT found; using adding OpenJDK 17 to the list of packages to install"
              PKGS+=( openjdk-17-jre-headless )
            fi
            ;;
        esac
        ;;
      *)
        # all other versions, use openjdk-8
        PKGS+=( openjdk-8-jre-headless )
        ;;
    esac
    ;;
  armv7l:false)
    # always use openjdk-8 for armv7l
    PKGS+=( openjdk-8-jre-headless )
    ;;
  *)
    die "${ARCH}: unsupported ARCH"
    ;;
esac

# output variables/selections
echo "ARCH=\"${ARCH}\""
echo "OMADA_URL=\"${OMADA_URL}\""
echo "OMADA_TAR=\"${OMADA_TAR}\""
echo "OMADA_VER=\"${OMADA_VER}\""
echo "OMADA_MAJOR_VER=\"${OMADA_MAJOR_VER}\""
echo "OMADA_MAJOR_MINOR_VER=\"${OMADA_MAJOR_MINOR_VER}\""
echo "PKGS=( ${PKGS[*]} )"

echo "**** Install Dependencies ****"
apt-get install --no-install-recommends -y "${PKGS[@]}"

echo "**** Download Omada Controller ****"
cd /tmp
wget -nv "${OMADA_URL}"

echo "**** Extract and Install Omada Controller ****"

# the beta versions are absolutely horrific in the file naming scheme - this mess tries to address and fix that bullshit
if [[ "${INSTALL_VER}" =~ ^beta.* ]]
then
  # get the extension to determine what to do with it
  case "${OMADA_URL##*.}" in
    zip)
      # this beta version is a tar.gz inside of a zip so let's pre-unzip it
      echo "INFO: this beta version is a zip file; unzipping..."
      # unzip the file
      unzip "${OMADA_TAR}"
      rm -f "${OMADA_TAR}"

      # whoever packages the beta up sucks at understanding file extensions
      FILENAME_CHECK="$(find . -name "*tar.gz*" | grep -v "zip" | sed 's|^./||')"

      # expect .tar.gz as the extension
      case "${FILENAME_CHECK}" in
        *.tar.gz)
          echo "INFO: filename extension for (${FILENAME_CHECK}) is '.tar.gz'; it's fine as is"
          ;;
        *_tar.gz.gz)
          echo "INFO: filename extension for (${FILENAME_CHECK}) is '_tar.gz.gz'; let's rename it to something sane"
          mv -v "${FILENAME_CHECK}" "${FILENAME_CHECK/_tar.gz.gz/.tar.gz}"
          ;;
        *tar.gz.gz)
          echo "INFO: filename extension for (${FILENAME_CHECK}) is 'tar.gz.gz'; let's rename it to something sane"
          mv -v "${FILENAME_CHECK}" "${FILENAME_CHECK/tar.gz.gz/.tar.gz}"
          ;;
        *)
          echo "WARN: the filename extension for (${FILENAME_CHECK}) is nothing that is expected; don't be surprised if one of the next steps fail!"
      esac

      # let's figure out where the tar.gz file is
      if [ -n "$(find . -name "*.tar.gz" -maxdepth 1 | sed 's|^./||')" ]
      then
        # it's in the current directory; just output message
        echo "INFO: .tar.gz is in the current directory, nothing to move"
      elif [ -n "$(find . -name "*.tar.gz" | sed 's|^./||')" ]
      then
        # it's in a subdirectory, move it to the current directory
        mv -v "$(find . -name "*.tar.gz" | sed 's|^./||')" .

        # cleanup directories
        # shellcheck disable=SC2044
        for DIR in $(find ./* -type d)
        do
          # cd to dir, find and delete any files; return
          cd "${DIR}"
          find . -type f -delete
          cd -
        done

        find ./* -type d -delete
      else
        echo "ERROR: unable to find a .tar.gz file!"
        exit 1
      fi

      # it's in the current directory; let's get the tar name
      OMADA_TAR="$(ls -- *.tar.gz)"
      ;;
    gz)
      # check to see if this is a tar.gz or just a gz
      if ls -- *.tar.gz >/dev/null 2>&1
      then
        # this is a .tar.gz
        echo "INFO: OMADA_TAR is a .tar.gz; we can handle it normally!"
      else
        # this beta version might be a tar.gz inside of a gzipped file so let's pre-gunzip it
        echo "INFO: this beta version is a .gz file; gunzipping..."
        # gunzip the file
        gunzip "${OMADA_TAR}"

        # now that we have unzipped, let's get the tar name
        OMADA_TAR="$(ls -- *.tar.gz*)"
      fi
      ;;
    *)
      echo "ERROR: unknown file extension, exiting!"
      exit 1
      ;;
  esac
fi

echo "${OMADA_TAR}"
ls -l "${OMADA_TAR}"
tar xvf "${OMADA_TAR}"
rm -f "${OMADA_TAR}"
cd Omada_SDN_Controller_*

# make sure tha the install directory exists
mkdir "${OMADA_DIR}" -vp

# starting with 5.0.x, the installation has no webapps directory; these values are pulled from the install.sh
case "${OMADA_MAJOR_VER}" in
  5)
    # see if we are running 5.3.x or greater by checking the minor version
    if [ "${OMADA_MAJOR_MINOR_VER#*.}" -ge 3 ]
    then
      # 5.3.1 and above moved the keystore directory to be a subdir of data
      NAMES=( bin data lib properties install.sh uninstall.sh )
    else
      # is less than 5.3
      NAMES=( bin data properties keystore lib install.sh uninstall.sh )
    fi
    ;;
  *)
    # isn't v5.x
    NAMES=( bin data properties keystore lib webapps install.sh uninstall.sh )
    ;;
esac

# copy over the files to the destination
for NAME in "${NAMES[@]}"
do
  cp "${NAME}" "${OMADA_DIR}" -r
done

# only add standlone options for controller version 5.x and above
case "${OMADA_MAJOR_VER}" in
  5)
    # add additional properties to the properties file
    { \
      echo "" ;\
      echo "" ;\
      echo "# external mongodb" ;\
      echo "mongo.external=false" ;\
      echo "eap.mongod.uri=mongodb://127.0.0.1:27217/omada" ;\
    } >> /opt/tplink/EAPController/properties/omada.properties
    ;;
esac

# copy omada default properties for can be used when properties is mounted as volume
cp -r /opt/tplink/EAPController/properties/ "${OMADA_DIR}/properties.defaults"

# symlink for mongod, if applicable
case "${NO_MONGODB}" in
  true)
    # do not include mongodb
    ;;
  *)
    # include mongodb
    ln -sf "$(command -v mongod)" "${OMADA_DIR}/bin/mongod"
    chmod 755 "${OMADA_DIR}"/bin/*
    ;;
esac

# starting with 5.0.x, the work directory is no longer needed
case "${OMADA_MAJOR_VER}" in
  5)
    # create logs directory
    mkdir "${OMADA_DIR}/logs"
    ;;
  *)
    # create logs and work directories
    mkdir "${OMADA_DIR}/logs" "${OMADA_DIR}/work"
    ;;
esac

# for v5.1 & above, create backup of data/html directory in case it is missing (to be extracted at runtime)
if [ -d /opt/tplink/EAPController/data/html ]
then
  # create backup
  cd /opt/tplink/EAPController/data
  tar zcvf ../data-html.tar.gz html
fi

echo "Setting permissions to 777 for the properties directory (required for rootless to function)"
chmod -R 777 /opt/tplink/EAPController/properties

echo "**** Cleanup ****"
rm -rf /tmp/* /var/lib/apt/lists/*

# write installed version to a file
echo "${OMADA_VER}" > "${OMADA_DIR}/IMAGE_OMADA_VER.txt"
