#!/bin/bash

################################################################
##############################################################
# <<  Release build-configuration — eSAI 1.1.0 (arm64 AC5X-RD)
SONIC_BRANCH=202605
SONIC_COMMIT_ID=3d22ec9
MRVLLIBSAI_VER=1.18.1-110
SAI_BINARIES_BRANCH=esai-202605-c110-aug12-candidate
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
        echo "ERROR: eSAI 1.1.0 (r_e110) supports arm64 only (AC5X-RD / CN913x)"
        exit 1
        ;;
esac

rBUILD_PLATFORM_ARCH="-a $rARCH"

if [[ -z "${rSAI_DEB}" && -n ${MRVLLIBSAI_VER} ]]; then
    if [ -f "./mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb" ]; then
        rSAI_DEB="--SAI $(realpath "./mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb")"
    else
        rSAI_DEB="--SAI https://github.com/Marvell-switching/sonic-marvell-binaries/raw/refs/heads/${SAI_BINARIES_BRANCH}/${rARCH}/sai-plugin/202605/mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb"
    fi
fi

rEXTRA_OPT=$@

#==============================================================================
SONIC_BUILD_SH_CMD="./sonic_build_script.sh $rBRANCH $rBUILD_PLATFORM $rBUILD_PLATFORM_ARCH \
 $rBUILD_ESAI $rEXTRA_PATCH_SETS $rBUILD_RPC $rBUILD_NO_CACHE $rCOMMIT_ID \
 $rPATCH_SCRIPT_PATH $rSAI_DEB $rEXTRA_OPT"

echo "========================================================================="
echo "<< Release build-configuration (eSAI 1.1.0 / r_e110)"
echo "SONIC_BRANCH=$SONIC_BRANCH"
echo "SONIC_COMMIT_ID=$SONIC_COMMIT_ID"
echo "MRVLLIBSAI_VER=$MRVLLIBSAI_VER"
echo "SAI_BINARIES_BRANCH=$SAI_BINARIES_BRANCH"
echo "CANONIC_BUILD=$CANONIC_BUILD"
echo ">>"
echo "Run in directory $(pwd)"
echo "$SONIC_BUILD_SH_CMD"
echo "-------------------------------------------------------------------------"
$SONIC_BUILD_SH_CMD
