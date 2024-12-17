#!/bin/bash

set -x

export PATH=/usr/lib/rstudio-server/bin:$PATH

RSERVER_ARGLIST=(
  "--server-working-dir" "${WORKING_DIR}"
  "--server-user" "$(whoami)"
  "--server-data-dir" "/tmp/run"
  "--www-address" "0.0.0.0"
  "--www-port" "${port}"
  "--rsession-path" "${RSESSION_WRAPPER_FILE}"
  "--auth-none" "0"
  "--auth-pam-helper-path" "${RSTUDIO_AUTH}"
  "--auth-encrypt-password" "0"
)
echo "RSERVER_ARGLIST=${RSERVER_ARGLIST[@]}"

RSERVER_ARGS="${RSERVER_ARGLIST[@]}"

echo "which rserver=$(which rserver)"

rserver ${RSERVER_ARGS}

echo "$?"
