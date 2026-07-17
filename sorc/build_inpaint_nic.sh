#! /usr/bin/env bash
set +x
function _usage() {
    cat << EOF
Builds ice pre-processing programs  

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

dirs=`ls -d inpaint*.fd`
codes=`echo $dirs | sed 's/\.fd/ /g'`
if [ ! -d "../exec" ]; then
   echo 'Creating exec directory'
   mkdir ../exec
fi

for i in  $codes
do
        cd ${i}.fd
        make clean > ${outfile} 2>> ${outfile}
        module list >> ${outfile} 2>> ${outfile}
        make >> ${outfile} 2>> ${outfile}
        mv $i ../../exec
        make clean
        cd ../
done
