#! /usr/bin/env bash
set +x
function _usage() {
    cat << EOF
Builds WW3 programs  

Usage: ${BASH_SOURCE[0]} [-d][-h]
  -d:
    Build in debug mode
  -j: 
    Build jobs (default 8)
  -v: 
    Verbose 
  -h:
    Print this help message and exit
EOF
    exit 1
}

set -x 

while getopts ":j:dv" option; do
    case "${option}" in
        d) BUILD_TYPE="Debug" ;;
        j) BUILD_JOBS="${OPTARG}" ;;
        v) export BUILD_VERBOSE="YES" ;;
        :)
            echo "[${BASH_SOURCE[0]}]: ${option} requires an argument"
            ;;
        *)
            echo "[${BASH_SOURCE[0]}]: Unrecognized option: ${option}"
            ;;
    esac
done

# shellcheck disable=SC2155
readonly HOMErwps=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")" && git rev-parse --show-toplevel)
cd "${HOMErwps}/sorc" || exit 1

source "${HOMErwps}/ush/detect_machine.sh"
set +x 
source "${HOMErwps}/ush/module-setup.sh"
source "${HOMErwps}/versions/build.ver"
module use ${HOMErwps}/modulefiles
module load build_ww3.${MACHINE_ID}
module list 
set -x 

ww3switch=model/bin/switch_NCEP_rwps

# Check final exec folder exists
finalexecdir=${HOMErwps}/exec
if [ ! -d "${finalexecdir}" ]; then
  mkdir -p ${finalexecdir}/exec
fi

#Set WW3 directory, switch, prep and post exes
cd "${HOMErwps}/sorc/ww3.fd" || exit 1
export WW3_DIR=$( pwd -P )
export SWITCHFILE="${WW3_DIR}/${ww3switch}"

# Build exes for prep jobs and post jobs:
prep_exes="ww3_grid ww3_prep ww3_prnc"
post_exes="ww3_outp ww3_gint ww3_ounf ww3_grib"
run_exes="ww3_multi ww3_shel"

#create build directory: 
path_build=${WW3_DIR}/build/SHRD
path_install=${WW3_DIR}/install/SHRD
if [[ -d "${path_build}" ]]; then
    rm -rf "${path_build}"
fi
mkdir -p "${path_build}" || exit 1
cd "${path_build}" || exit 1
echo "Forcing a SHRD build"

buildswitch="${path_build}/switch"

echo $(cat ${SWITCHFILE}) > ${path_build}/tempswitch

sed -e "s/DIST/SHRD/g"\
    -e "s/OMPG / /g" \
    -e "s/OMPH / /g" \
    -e "s/MPIT / /g" \
    -e "s/MPI / /g" \
    -e "s/PIO / /g" \
    -e "s/B4B / /g" \
    -e "s/PDLIB / /g" \
    -e "s/SCOTCH / /g" \
    -e "s/METIS / /g" \
    -e "s/NOGRB/NCEP2/g" \
       ${path_build}/tempswitch > ${path_build}/switch
rm ${path_build}/tempswitch

echo "Switch file is ${buildswitch} with switches:"
cat "${buildswitch}"

#define cmake build options
MAKE_OPT="-DCMAKE_INSTALL_PREFIX=${path_install}"
if [[ "${BUILD_TYPE:-"Release"}" == "Debug" ]]; then
    MAKE_OPT+=" -DCMAKE_BUILD_TYPE=Debug"
fi

#Build executables: 
cmake "${WW3_DIR}" -DSWITCH="${buildswitch}" ${MAKE_OPT}
rc=$?
if ((rc != 0)); then
    echo "Fatal error in cmake."
    echo "rc=${rc}"
    exit "${rc}"
fi

make -j "${BUILD_JOBS:-8}"
rc=$?
if ((rc != 0)); then
    echo "Fatal error in make."
    exit "${rc}"
fi

make install
if ((rc != 0)); then
    echo "Fatal error in make install."
    exit "${rc}"
fi

#TO DO: Use ww3_* names and move this to linking script
# Copy to top-level exe directory
cp ${path_install}/bin/ww3_grid $finalexecdir/wavegrid
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_grid to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_prep $finalexecdir/waveprep
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prep to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_prnc $finalexecdir/waveprnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prnc to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_outp $finalexecdir/wavespec
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_outp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_gint $finalexecdir/wavegrid_interp
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_gint to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_ounf $finalexecdir/wavefldn
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounf to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_ounp $finalexecdir/wavespnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_grib $finalexecdir/wavegrib2
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_grib to $finalexecdir (Error code $rc)"
  exit $rc
fi

#create run build directory: 
path_build=${WW3_DIR}/build/DIST
path_install=${WW3_DIR}/install/DIST
if [[ -d "${path_build}" ]]; then
    rm -rf "${path_build}"
fi
mkdir -p "${path_build}" || exit 1
cd "${path_build}" || exit 1


echo "Building a DIST build" 

echo $(cat ${SWITCHFILE}) > ${path_build}/runswitch

echo "Switch file is $path_build/switch with switches:" 
cat $path_build/runswitch

#Build executables: 
MAKE_OPT="-DCMAKE_INSTALL_PREFIX=${path_install}"
if [[ "${BUILD_TYPE:-"Release"}" == "Debug" ]]; then
    MAKE_OPT+=" -DCMAKE_BUILD_TYPE=Debug"
fi

#Build executables: 
cmake "${WW3_DIR}" -DSWITCH="${path_build}/runswitch" ${MAKE_OPT}
rc=$?
if ((rc != 0)); then
    echo "Fatal error in cmake."
    exit "${rc}"
fi

make -j "${BUILD_JOBS:-8}"
rc=$?
if ((rc != 0)); then
    echo "Fatal error in make."
    exit "${rc}"
fi

make install
if ((rc != 0)); then
    echo "Fatal error in make install."
    exit "${rc}"
fi

# Copy to top-level exe directory
cp ${path_install}/bin/ww3_multi $finalexecdir/wavefcst
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy ${path_install}/bin/ww3_multi to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/bin/ww3_shel $finalexecdir/ww3_shel
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy ${path_install}/bin to $finalexecdir (Error code $rc)"
  exit $rc
fi

wait
exit 0 
