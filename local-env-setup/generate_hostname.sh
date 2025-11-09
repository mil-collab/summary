#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="$1"

echo "${SERVICE}.$(${SCRIPT_DIR}/get_ccm_ip.sh).sslip.io"
