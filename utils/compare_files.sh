#!/bin/bash

set -e

GA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=6.0")"
BETA_URL="$(wget -q -O - "https://omada-controller-url.mbentley.net/hooks/omada_ver_to_url?omada-ver=beta")"

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

cd ga
wget -q --show-progress "${GA_URL}"
GA_TAR="$(ls)"
cd ..

cd beta
wget -q --show-progress "${BETA_URL}"
BETA_TAR="$(ls)"
cd ..

echo ""

# extract GA version (.tar.gz)
echo "INFO: extracting GA version..."
cd "${TEMP_DIR}/ga" || exit 1
tar xzf "${GA_TAR}"

# extract BETA version (.tar.gz.zip)
echo "INFO: extracting BETA version..."
cd "${TEMP_DIR}/beta" || exit 1
unzip -q "${BETA_TAR}"
tar xzf *.tar.gz
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
