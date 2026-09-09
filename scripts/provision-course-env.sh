#!/usr/bin/env bash
# Provisions one course's batch-job configuration: the R library directory, and
# the course-env.sh that run-r-job.sh reads at run time.
#
#   provision-course-env.sh --canvas-id <id> --image <imagefile> \
#       [--r-version <ver>] [--arch <arch>] [--dry-run]
#
# RUN ON THE HEAD NODE, AS ROOT. The course folder is 2775, owned by the course
# staff group, and its parent is 750 owned by the enrollment group -- so an
# administrator who is not in those groups cannot traverse to it at all. root on
# the head node is the only context that reliably can.
#
# Unlike the environment provisioning in ood-apptainer-apps, this needs no
# compute and no container: it writes two values and makes a directory. It is
# deliberately NOT an sbatch job.
#
# WHY IT EXISTS AT ALL. course-env.sh names the current image and course
# library. The wrapper reads it on every run rather than baking the values in,
# so changing the image here reaches every copy a student has ever taken --
# including one taken months earlier. Without this file the wrapper falls back
# to values frozen when the session rendered it, which works but silently loses
# that property.
#
# Safe to re-run. Rewrites course-env.sh; leaves an existing library alone.
set -uo pipefail

this_script="scripts/provision-course-env.sh"

warnings=0
fail() { echo "ERROR: ${this_script}: $1" >&2; exit 1; }
log()  { echo "${this_script}: $1"; }
# A warning is for something that went wrong but does not invalidate the rest of
# the run. The script still exits non-zero at the end, so a caller sees it, but
# it does not abandon work that has nothing to do with the failure.
warn() { echo "WARNING: ${this_script}: $1" >&2; warnings=$((warnings + 1)); }

usage() {
    cat >&2 <<USAGE
usage: $0 --canvas-id <id> --image <imagefile> [--r-version <ver>] [--arch <arch>] [--dry-run]

  --canvas-id   Canvas course id, e.g. 170320. The course folder is derived from
                it by the same convention the sub-apps use.
  --image       image filename under the shared image root, e.g. rstudio-base.sif
  --r-version   R major.minor, default 4.5. MUST match the image's R: the library
                path ends in this, and an image on a different R orphans every
                package in it, silently.
  --arch        R platform string, default x86_64-pc-linux-gnu
  --dry-run     print what would be written and change nothing
USAGE
    exit 64
}

CANVAS_ID=""; IMAGE_FILE=""; R_VERSION="4.5"; ARCH="x86_64-pc-linux-gnu"; DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --canvas-id)  [ $# -ge 2 ] || usage; CANVAS_ID="$2";  shift 2 ;;
        --image)      [ $# -ge 2 ] || usage; IMAGE_FILE="$2"; shift 2 ;;
        --r-version)  [ $# -ge 2 ] || usage; R_VERSION="$2";  shift 2 ;;
        --arch)       [ $# -ge 2 ] || usage; ARCH="$2";       shift 2 ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)    usage ;;
        *)            echo "ERROR: unknown flag: $1" >&2; usage ;;
    esac
done

[ -n "$CANVAS_ID" ] && [ -n "$IMAGE_FILE" ] || usage
case "$CANVAS_ID" in ''|*[!0-9]*) fail "--canvas-id must be digits, got '${CANVAS_ID}'" ;; esac

# --- Derive every path, by the same convention the sub-apps use --------------
COURSE_SHARED_ROOT="${OOD_COURSE_SHARED_ROOT:-/shared/courseSharedFolders}"
IMAGE_ROOT="${OOD_IMAGE_ROOT:-/shared/apptainerImages}"

COURSE_FOLDER="${COURSE_SHARED_ROOT}/${CANVAS_ID}outer/${CANVAS_ID}"
IMAGE_PATH="${IMAGE_ROOT}/${IMAGE_FILE}"
R_LIB="${COURSE_FOLDER}/R/${ARCH}-library/${R_VERSION}"
ENV_FILE="${COURSE_FOLDER}/course-env.sh"

log "course_folder=${COURSE_FOLDER}"
log "image=${IMAGE_PATH}"
log "r_lib=${R_LIB}"
log "env_file=${ENV_FILE}"

# --- Checks that must hold before anything is written ------------------------
[ -d "$COURSE_FOLDER" ] || fail "course folder '${COURSE_FOLDER}' does not exist. It is created by /etc/ood/add_user.sh at a course member's first login, not by this script."
[ -r "$IMAGE_PATH" ]    || fail "image '${IMAGE_PATH}' is not readable"

# The R version is load-bearing, so check it rather than trust the flag. Skipped
# rather than fatal when apptainer is unavailable: on a head node without spack
# this script is still useful, and the flag is still the operator's statement.
if command -v apptainer >/dev/null 2>&1; then
    image_r=$(apptainer exec "$IMAGE_PATH" R --version 2>/dev/null | sed -n '1s/.*version \([0-9]*\.[0-9]*\).*/\1/p')
    if [ -n "$image_r" ] && [ "$image_r" != "$R_VERSION" ]; then
        fail "image reports R ${image_r} but --r-version is ${R_VERSION}. The library path ends in the version, so this would orphan every package in it."
    fi
    [ -n "$image_r" ] && log "image R version confirmed: ${image_r}"
else
    log "apptainer not on PATH; skipping the R version check (--r-version ${R_VERSION} taken on trust)"
fi

ENV_CONTENT="# Written by ${this_script}. Do not edit by hand.
#
# The two values a batch job needs that differ between courses. run-r-job.sh
# reads this file every time it runs, so changing the image or the library here
# reaches every copy a student has taken, however old.
IMAGE=\"${IMAGE_PATH}\"
R_LIB=\"${R_LIB}\""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "--- would create (if missing): ${R_LIB}"
    echo "--- would write: ${ENV_FILE}"
    printf '%s\n' "$ENV_CONTENT"
    exit 0
fi

# --- The R library directory -------------------------------------------------
# setgid so packages a staff member installs later inherit the course staff
# group, which is what keeps them readable to students without a chmod pass.
if [ -d "$R_LIB" ]; then
    log "R library already exists, leaving it alone: ${R_LIB}"
else
    mkdir -p "$R_LIB" || fail "cannot create '${R_LIB}'"
    log "created R library: ${R_LIB}"
    # Not fatal, and deliberately so: the mode matters, but it is unrelated to
    # course-env.sh, which is the file the wrapper actually reads. Refusing to
    # write that because a chmod failed would couple two independent things.
    if ! chmod 2775 "$R_LIB"; then
        warn "could not chmod 2775 '${R_LIB}'. Packages installed there may not inherit the course staff group, and students may not be able to read them. Run the course folder's fix-permissions.sh, or set it by hand."
    fi
fi

# --- course-env.sh -----------------------------------------------------------
# 644: every course member reads it at job run time; only provisioning writes it.
# Written to a temp file and moved into place, because a job sourcing it midway
# through a partial write would fail in a way nobody would think to look for.
tmp="${ENV_FILE}.$$.tmp"
printf '%s\n' "$ENV_CONTENT" > "$tmp" || fail "cannot write '${tmp}'"
chmod 644 "$tmp" || { rm -f "$tmp"; fail "cannot chmod '${tmp}'"; }
mv -f "$tmp" "$ENV_FILE" || { rm -f "$tmp"; fail "cannot move into place '${ENV_FILE}'"; }
log "wrote ${ENV_FILE}"

if [ "$warnings" -gt 0 ]; then
    log "done, with ${warnings} warning(s) above. course-env.sh was written."
    exit 1
fi

log "done. Verify from a session: sbatch ~/<course>-job-tools/run-r-job.sh <script>.R"
