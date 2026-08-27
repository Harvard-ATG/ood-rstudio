#!/bin/bash

set -x

# NOTE: rserver rebuilds the environment for each R session, so PATH set here
# does NOT reach the user's R console or Terminal pane - only rserver itself.
# Anything a session must see on PATH has to be set in the generated rsession.sh
# wrapper (for R) or in an /etc/profile.d drop-in (for terminal shells); both are
# done in template/script.sh.erb. This is why the Slurm client, when a sub-app
# enables it, is not put on PATH from this file.
export PATH=/usr/lib/rstudio-server/bin:$PATH

RSERVER_ARGLIST=(
  "--server-working-dir" "${WORKING_DIR}"
  "--server-user" "$(whoami)"
  "--server-data-dir" "/tmp/$(whoami)/run"
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
