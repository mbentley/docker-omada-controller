#!/bin/bash

# get cpu architecture
ARCH="$(uname -m)"

case "${ARCH}" in
  x86_64)
    # amd64 checks
    echo "INFO: running hardware prerequisite check for AVX support on ${ARCH} to ensure your system can run MongoDB 8..."

    # check for AVX support
    if ! grep -qE '^flags.* avx( .*|$)' /proc/cpuinfo
    then
      echo "ERROR: your system does not support AVX which is a requirement for the v6 and above container image as it only ships with MongoDB 8"
      echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and how you can address this"
      exit 1
    else
      echo "INFO: AVX support detected; v6 of the controller image (MongoDB 8) should run on your system!"
    fi
    ;;
  aarch64|aarch64_be|armv8b|armv8l)
    # arm64 checks (list of 64 bit arm compatible names from `uname -m`: https://stackoverflow.com/a/45125525)
    echo "INFO: running hardware prerequisite check for armv8.2-a support on ${ARCH} to ensure your system can run MongoDB 8..."

    # check for armv8.2-a support
    if ! grep -qE '^Features.* (fphp|dcpop|sha3|sm3|sm4|asimddp|sha512|sve)( .*|$)' /proc/cpuinfo
    then
      # failed armv8.2-a test
      echo "ERROR: your system does not support the armv8.2-a or later microarchitecture which is a requirement for the v6 and above container image as it only ships with MongoDB 8"
      echo "  See https://github.com/mbentley/docker-omada-controller/blob/master/KNOWN_ISSUES.md#your-system-does-not-support-avx-or-armv82-a for details on what exactly this means and how you can address this"
      exit 1
    else
      echo "INFO: armv8.2-a and above CPU features detected; v6 of the controller image (MongoDB 8) should run on your system!"
    fi
    ;;
  *)
    echo -e "\nERROR: unknown architecture (${ARCH})"
    exit 1
    ;;
esac

# prerequisite checks successful
echo "done"