#! /usr/bin/env bash
set +x
function _usage() {
    cat << EOF
Builds WW3 programs  

Usage: ${BASH_SOURCE[0]} [-d][-h]
  -d:
    Build in debug mode
  -h:
    Print this help message and exit
EOF
    exit 1
}

set -x 

# shellcheck disable=SC2155
readonly HOMErwps_=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")" && git rev-parse --show-toplevel)
cd "${HOMErwps_}/sorc" || exit 1

source "${HOMErwps_}/ush/detect_machine.sh"
source "${HOMErwps}/ush/module-setup.sh"
source "${HOMErwps_}/versions/build.ver"

set +x
module purge
module use ${HOMErwps_}/modulefiles
module load build_ww3.${MACHINE_ID}.module
module list 
set -x 

ww3switch=model/bin/switch_NCEP_rwps

# Check final exec folder exists
finalexecdir=${HOMErwps_}/exec
if [ ! -d "${finalexecdir}" ]; then
  mkdir -p ${finalexecdir}/exec
fi

#Set WW3 directory, switch, prep and post exes
cd "${HOMErwps_}/sorc/ww3.fd" || exit 1
export WW3_DIR=$( pwd -P )
export SWITCHFILE="${WW3_DIR}/${ww3switch}"

# Build exes for prep jobs and post jobs:
prep_exes="ww3_grid ww3_prep ww3_prnc"
post_exes="ww3_outp ww3_gint ww3_ounf ww3_grib"
run_exes="ww3_multi"

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
    -e "s/OMPG / /g"\
    -e "s/OMPH / /g"\
    -e "s/MPIT / /g"\
    -e "s/MPI / /g"\
    -e "s/B4B / /g"\
    -e "s/PDLIB / /g"\
    -e "s/NOGRB/NCEP2/g"\
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
    exit "${rc}"
fi

make -j 8
rc=$?
if ((rc != 0)); then
    echo "Fatal error in cmake."
    exit "${rc}"
fi

make install
if ((rc != 0)); then
    echo "Fatal error in cmake."
    exit "${rc}"
fi

#TO DO: Use ww3_* names and move this to linking script
# Copy to top-level exe directory
cp $${path_install}/ww3_grid $finalexecdir/wavegrid
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_grid to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_prep $finalexecdir/waveprep
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prep to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_prnc $finalexecdir/waveprnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prnc to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_outp $finalexecdir/wavespec
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_outp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_gint $finalexecdir/wavegrid_interp
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_gint to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_ounf $finalexecdir/wavefldn
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounf to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_ounp $finalexecdir/wavespnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_grib $finalexecdir/wavegrib2
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

make -j 8
rc=$?
if ((rc != 0)); then
    echo "Fatal error in cmake."
    exit "${rc}"
fi

make install
if ((rc != 0)); then
    echo "Fatal error in cmake."
    exit "${rc}"
fi

# Copy to top-level exe directory
cp ${path_install}/ww3_multi $finalexecdir/wavefcst
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_multi to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp ${path_install}/ww3_shel $finalexecdir/ww3_shel
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_shel to $finalexecdir (Error code $rc)"
  exit $rc
fi

