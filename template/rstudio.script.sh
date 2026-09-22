#!/bin/bash

set -x

# What is this for?
#
# This path points to the folder containing RStudio Server's own programs,
# including `rsession`, which runs the R console, and `rpostback`.
#
# This PATH is for `rserver` itself. It is not the PATH a student sees in
# RStudio. RStudio starts the R console and the Terminal separately:
#
#   R console  -> rsession
#   Terminal   -> bash
#
# Each needs its own PATH setting. `script.sh.erb` adds Slurm commands to
# `rsession.sh` for the R console and to `/etc/profile.d/zz-slurm.sh` for the
# Terminal.
#
# To see the difference, open the RStudio Terminal and run:
#
#   echo $PATH
#
# `/usr/lib/rstudio-server/bin` will not appear there, even though it is added
# below for `rserver`.
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
