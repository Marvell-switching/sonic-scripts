#!/bin/bash

################################################################
##############################################################
# <<  Release build-configuration — eSAI 2.0.0 (arm64 AC5X-RD)
SONIC_BRANCH=202605
SONIC_COMMIT_ID=bea8fa9b1
MRVLLIBSAI_VER=1.18.1-200
##CANONIC_BUILD=Y
# >>
# echo/print is at the end
##############################################################
################################################################

rBUILD_PLATFORM="-p marvell-prestera"
rBUILD_ESAI="--eSAI"
rBUILD_RPC="-r"
rBUILD_NO_CACHE="--no-cache"

if [ -n "${SONIC_BRANCH}" ]; then
    rBRANCH="-b $SONIC_BRANCH"
fi
if [ -n "${SONIC_COMMIT_ID}" ]; then
    rCOMMIT_ID="-c $SONIC_COMMIT_ID"
fi
if [ -z "${CANONIC_BUILD}" ]; then
    rPATCH_SCRIPT_PATH="--patch_script $(realpath "$(pwd)/marvell_sonic_patch_script.sh")"
fi

SONIC_TARGET_ARCH="${SONIC_TARGET_ARCH:-$(uname -m)}"
case "$SONIC_TARGET_ARCH" in
    aarch64|armv8l)    rARCH="arm64"  ;;
    *)
        echo "ERROR: eSAI 2.0.0 (r_e200) supports arm64 only (AC5X-RD / CN913x)"
        exit 1
        ;;
esac

rBUILD_PLATFORM_ARCH="-a $rARCH"

#rSAI_DEB="--SAI `pwd`/mrvllibsai_1.18.1-200_${rARCH}.deb"
#rSAI_DEB="--SAI <URL>/mrvllibsai_1.18.1-200_${rARCH}.deb"
#---------
if [[ -z "${rSAI_DEB}" && -n ${MRVLLIBSAI_VER} ]]; then
    rSAI_VER="--SAI_VER ${MRVLLIBSAI_VER}"
    if [ -f "./mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb" ]; then
        rSAI_DEB="--SAI `pwd`/mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb"
    fi
fi

rEXTRA_OPT=$@

#==============================================================================
SONIC_BUILD_SH_CMD="./sonic_build_script.sh $rBRANCH $rBUILD_PLATFORM $rBUILD_PLATFORM_ARCH \
 $rBUILD_ESAI $rEXTRA_PATCH_SETS $rBUILD_RPC $rBUILD_NO_CACHE $rCOMMIT_ID \
 $rPATCH_SCRIPT_PATH $rSAI_VER $rSAI_DEB $rEXTRA_OPT"

echo "========================================================================="
echo "<< Release build-configuration (eSAI 2.0.0 / r_e200)"
echo "SONIC_BRANCH=$SONIC_BRANCH"
echo "SONIC_COMMIT_ID=$SONIC_COMMIT_ID"
echo "MRVLLIBSAI_VER=$MRVLLIBSAI_VER"
echo "CANONIC_BUILD=$CANONIC_BUILD"
echo ">>"
echo "Run in directory $(pwd)"
echo "$SONIC_BUILD_SH_CMD"
echo "-------------------------------------------------------------------------"
$SONIC_BUILD_SH_CMD
