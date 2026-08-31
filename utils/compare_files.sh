#!/bin/bash

set -e

GA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=6.3")"
BETA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=beta")"
#BETA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=beta-6.3.0.36")"

# CACHE=true will store downloaded files in CACHE_DIR and reuse them on subsequent runs
CACHE="${CACHE:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/.cache"

# fetch a URL into DEST_DIR, using/populating CACHE_DIR when CACHE=true
download_file() {
  local URL="$1"
  local DEST_DIR="$2"
  local FILENAME
  FILENAME="$(basename "${URL}")"

  if [ "${CACHE}" = "true" ] && [ -f "${CACHE_DIR}/${FILENAME}" ]
  then
    echo "INFO: found cached file, skipping download: ${FILENAME}"
    cp "${CACHE_DIR}/${FILENAME}" "${DEST_DIR}/${FILENAME}"
    return
  fi

  (cd "${DEST_DIR}" && wget -q --show-progress "${URL}")

  if [ "${CACHE}" = "true" ]
  then
    mkdir -p "${CACHE_DIR}"
    echo "INFO: caching downloaded file: ${FILENAME}"
    cp "${DEST_DIR}/${FILENAME}" "${CACHE_DIR}/${FILENAME}"
  fi
}

# create temp directory
TEMP_DIR="$(mktemp -d)"

# cleanup temp directory on exit (handles errors and normal exits)
trap 'echo "INFO: cleaning up temp directory: ${TEMP_DIR}"; rm -rf "${TEMP_DIR}"' EXIT

cd "${TEMP_DIR}"

# create subdirectories for each version
mkdir -p ga beta

# download the latest versions
echo "INFO: downloading the latest GA and Beta versions..."
echo "  GA URL: ${GA_URL}"
echo "  BETA URL: ${BETA_URL}"

download_file "${GA_URL}" "${TEMP_DIR}/ga"
GA_TAR="$(ls "${TEMP_DIR}/ga")"

download_file "${BETA_URL}" "${TEMP_DIR}/beta"
BETA_TAR="$(ls "${TEMP_DIR}/beta")"

echo ""

# extract GA version (.tar.gz)
echo "INFO: extracting GA version..."
cd "${TEMP_DIR}/ga" || exit 1
tar xzf "${GA_TAR}"

# extract BETA version (may be a plain .tar.gz or a .tar.gz wrapped in a .zip)
echo "INFO: extracting BETA version..."
cd "${TEMP_DIR}/beta" || exit 1
case "${BETA_TAR}" in
  *.zip)
    unzip -q "${BETA_TAR}"
    tar xzf *.tar.gz
    ;;
  *.tar.gz)
    tar xzf "${BETA_TAR}"
    ;;
  *)
    echo "ERROR: unknown file extension for BETA_TAR (${BETA_TAR})"
    exit 1
    ;;
esac
cd "${TEMP_DIR}" || exit 1

echo ""

# find the extracted directories (get just the directory names)
GA_DIR_NAME="$(cd ga && ls -d Omada_*/ 2>/dev/null | sed 's|/$||')"
BETA_DIR_NAME="$(cd beta && ls -d Omada_*/ 2>/dev/null | sed 's|/$||')"

echo "INFO: GA directory: ga/${GA_DIR_NAME}"
echo "INFO: BETA directory: beta/${BETA_DIR_NAME}"
echo ""

# compare install.sh files
echo "========================================"
echo "Comparing install.sh"
echo "========================================"
if git diff --no-index --color=always --src-prefix= --dst-prefix= \
  "ga/${GA_DIR_NAME}/install.sh" "beta/${BETA_DIR_NAME}/install.sh"
then
  echo "INFO: install.sh files are identical"
else
  echo "INFO: install.sh files differ (see above)"
fi
echo ""

# compare properties/omada.properties files
echo "========================================"
echo "Comparing properties/omada.properties"
echo "========================================"
if git diff --no-index --color=always --src-prefix= --dst-prefix= \
  "ga/${GA_DIR_NAME}/properties/omada.properties" "beta/${BETA_DIR_NAME}/properties/omada.properties"
then
  echo "INFO: properties/omada.properties files are identical"
else
  echo "INFO: properties/omada.properties files differ (see above)"
fi
echo ""

echo "INFO: comparison complete!"
