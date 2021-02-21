#!/bin/sh

wget --quiet --tries=1 --no-check-certificate -O /dev/null --server-response --timeout=5 "https://127.0.0.1:${MANAGE_HTTPS_PORT:-8043}/login" || exit 1
