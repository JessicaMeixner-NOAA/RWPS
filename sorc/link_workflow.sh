#!/bin/bash
#--make symbolic links for EMC installation and hardcopies for NCO delivery

HOMErwps=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")" > /dev/null 2>&1 && git rev-parse --show-toplevel)

function usage() {
    cat << EOF
Builds all of the global-workflow components by calling the individual build
  scripts in sequence.

Usage: ${BASH_SOURCE[0]} [-h][-o][--nest]
  -h:
    Print this help message and exit
  -o:
    Configure for NCO (copy instead of link)
EOF
    exit 1
}

RUN_ENVIR="emc"

# Reset option counter in case this script is sourced
OPTIND=1
while getopts ":ho-:" option; do
    case "${option}" in
        h) usage ;;
        o)
            echo "-o option received, configuring for NCO"
            RUN_ENVIR="nco"
            ;;
        -)
            if [[ "${OPTARG}" == "nest" ]]; then
                LINK_NEST=ON
            fi
            ;;
        :)
            echo "[${BASH_SOURCE[0]}]: ${option} requires an argument"
            usage
            ;;
        *)
            echo "[${BASH_SOURCE[0]}]: Unrecognized option: ${option}"
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

# LINK is always ln, LINK_OR_COPY can be ln or cp depending on RUN_ENVIR being emc or nco, respectively
LINK="ln -fs"
if [[ "${RUN_ENVIR}" == "nco" ]]; then
    LINK_OR_COPY="cp -rp"
else
    LINK_OR_COPY="ln -fs"
fi

# Re-linking a directory under a name isn't idempotent: if link_workflow.sh is
# called again, the previous run's link at dest makes ln/cp nest the result
# inside it instead of replacing it. A similar issue occurs with spurious copying.
# guard() deletes the resolved target first so reruns stay clean.
function guard() {
    local src=$1
    local dest=$2

    # "." (or "dir/", "dir/.") means ln/cp place the result *inside* that
    # directory as dest/<basename>; anything else is the literal target name.
    # Resolve that path so we remove exactly what the link/copy will create.
    local link_name
    if [[ "${dest}" == "." ]]; then
        link_name="$(basename "${src}")"
    elif [[ "${dest}" == */ || "${dest}" == */. ]]; then
        link_name="${dest%/*}/$(basename "${src}")"
    else
        link_name="${dest}"
    fi

    # guard requires permission to delete existing copies of ${link_name}
    if [[ "${RUN_ENVIR}" == "nco" && -d "${link_name}" && ! -L "${link_name}" ]]; then
        chmod -R 755 "${link_name}"
    fi

    # clean up the resolved name to prevent recursive linking / nested copies
    rm -rf "${link_name}"
}

# this wrapper for ${LINK} calls the guard to link safely
# usage: safe_link <src> <dest>
function safe_link() {
    guard "$1" "$2"
    ${LINK} "$1" "$2"
}

# this wrapper for ${LINK_OR_COPY} calls the guard to link/copy safely
# usage: safe_link <src> <dest>
function safe_link_or_copy() {
    guard "$1" "$2"
    ${LINK_OR_COPY} "$1" "$2"
}

# shellcheck disable=SC1091
COMPILER="intel" source "${HOMErwps}/ush/detect_machine.sh" # (sets MACHINE_ID)
# shellcheck disable=
machine=$(echo "${MACHINE_ID}" | cut -d. -f1)

#------------------------------
#--Set up build.ver and run.ver
#------------------------------
safe_link_or_copy "${HOMErwps}/versions/build.${machine}.ver" "${HOMErwps}/versions/build.ver"
safe_link_or_copy "${HOMErwps}/versions/run.${machine}.ver" "${HOMErwps}/versions/run.ver"

#------------------------------
#--model fix fields
#------------------------------
case "${machine}" in
    "wcoss2") FIX_DIR="/lfs/h2/emc/couple/noscrub/keston.smith/RWPS/fix" ;;
    "ursa" ) FIX_DIR="/scratch3/NCEPDEV/climate/Jessica.Meixner/RWPS/fix" ;;
    "orion" | "hercules") FIX_DIR="/work2/noaa/marine/keston/RWPS/fix" ;;
    *)
        echo "FATAL: Unknown target machine ${machine}, couldn't set FIX_DIR"
        exit 1
        ;;
esac

# Source fix version file
source "${HOMErwps}/versions/fix.ver"

# Link fix directories
if [[ -n "${FIX_DIR}" ]]; then
    mkdir -p "${HOMErwps}/fix" || exit 1
fi
cd "${HOMErwps}/fix" || exit 1

for dir in oc_10km_200km \
    oc_20km_300km \
    oc_5km_100km \
    oc_1500m_30km \
    oc_500m_10km; do 
    fix_ver="${dir}_ver"
    safe_link_or_copy "${FIX_DIR}/${dir}/${!fix_ver}" "${dir}"
done

