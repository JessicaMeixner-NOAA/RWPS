#!/usr/bin/env bash

function _usage() {
    cat << EOF
Builds all of the RWPS components 

Usage: ${BASH_SOURCE[0]} [-h][-d]
  -h:
    Print this help message and exit
  -d Build in debug mode (DEFAULT: NO)
EOF
    exit 1
}

set -eu
debug_opt=""

while getopts "hd" option; do
    case "${option}" in
        h) _usage ;;
        d) debug_opt="--debug" ;;
        *)
            echo "[${BASH_SOURCE[0]}]: Unrecognized option: ${option}"
            _usage
            ;;
    esac
done

# shellcheck disable=SC2155
readonly HOMErwps=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/.." && pwd -P)

echo HOMErwps=${HOMErwps}
#------------------------------------
# GET MACHINE
#------------------------------------
export COMPILER="intel"
source "${HOMErwps}/ush/detect_machine.sh"
source "${HOMErwps}/ush/module-setup.sh"
if [[ -z "${MACHINE_ID}" ]]; then
    echo "FATAL: Unable to determine target machine"
    exit 1
fi

#------------------------------------
# SOURCE BUILD VERSION FILES
#------------------------------------
cd "${HOMErwps}/versions" || exit 1
ln -sf "${HOMErwps}"/versions/build."${MACHINE_ID}".ver "${HOMErwps}"/versions/build.ver
source "${HOMErwps}"/versions/build.ver

cd "${HOMErwps}/sorc" || exit 1

#------------------------------------
# Set build logs directory 
#------------------------------------
build_dir=`pwd`
logs_dir=$build_dir/logs
if [ ! -d $logs_dir  ]; then
  echo "Creating logs folder"
  mkdir $logs_dir
fi

#------------------------------------
# Check final exec folder exists
#------------------------------------
if [ ! -d "../exec" ]; then
  echo "Creating ../exec folder"
  mkdir ../exec
fi

#------------------------------------
# Exception Handling Init
#------------------------------------
ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
err=0

#------------------------------------
# build ww3
#------------------------------------
echo " .... Building ww3 .... "
set +e 
./build_ww3.sh ${debug_opt} > $logs_dir/build_ww3.log 2>&1
rc=$?
set -e 
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in building ww3."
    echo "The log file is in $logs_dir/build_ww3.log"
fi
err=$((err+rc))

#------------------------------------
# build inpaint_nic 
#------------------------------------
echo " .... Building inpaint_nic .... "
cd "${HOMErwps}/sorc" || exit 1
set +e
./build_inpaint_nic.sh ${debug_opt} > $logs_dir/build_inpaint_nic.log 2>&1
rc=$?
set -e
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in building inpaint_nic."
    echo "The log file is in $logs_dir/build_inpaint_nic.log"
fi
err=$((err+rc))


#------------------------------------
# Exception Handling
#------------------------------------
if ((err != 0)); then
    cat << EOF
BUILD ERROR: One or more components failed to build
  Check the associated build log(s) for details.
EOF
    ${ERRSCRIPT} || exit "${err}"
fi

echo
echo " .... Build system finished .... "

exit 0
