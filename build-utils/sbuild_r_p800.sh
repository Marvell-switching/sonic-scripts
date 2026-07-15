#!/bin/bash

################################################################
##############################################################
# <<  Release build-configuration
SONIC_BRANCH=202605
SONIC_COMMIT_ID=63f17ae50
#MRVLLIBSAI_VER=1.18.1-1     - already set as 202605 Default
##CANONIC_BUILD=Y
#MV_EXTRA_PATCH_SETS=Y
# >>
# echo/print is at the end
##############################################################
################################################################

rBUILD_PLATFORM="-p marvell-prestera"
rBUILD_RPC="-r"
#rBUILD_SAISERVER="-s"
rBUILD_NO_CACHE="--no-cache"

if [ -n "${SONIC_BRANCH}" ]; then
    rBRANCH="-b $SONIC_BRANCH"
fi
if [ -n "${SONIC_COMMIT_ID}" ]; then
    rCOMMIT_ID="-c $SONIC_COMMIT_ID"
fi
if [ -z "${CANONIC_BUILD}" ]; then
    rPATCH_SCRIPT_PATH="--patch_script `pwd`/marvell_sonic_patch_script.sh"
fi

SONIC_TARGET_ARCH="${SONIC_TARGET_ARCH:-$(uname -m)}"
  case "$SONIC_TARGET_ARCH" in
    x86_64|i386|i686)  rARCH="amd64"  ;;
    aarch64|armv8l)    rARCH="arm64"  ;;
    armv7l|armhf)      rARCH="armhf"  ;;
    *)        echo "ERROR: build-target-arch is unknown" ;;
  esac

rBUILD_PLATFORM_ARCH="-a $rARCH"

#rSAI_DEB="--SAI `pwd`/mrvllibsai_1.18.1-nn_${rARCH}.deb"
#rSAI_DEB="--SAI <URL>/mrvllibsai_1.18.1-nn_${rARCH}.deb"
#---------
if [[ -z "${rSAI_DEB}" && -n ${MRVLLIBSAI_VER} ]]; then
    rSAI_VER="--SAI_VER ${MRVLLIBSAI_VER}"
    if [ -f "./mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb" ]; then
        rSAI_DEB="--SAI `pwd`/mrvllibsai_${MRVLLIBSAI_VER}_${rARCH}.deb"
    fi
fi

rEXTRA_OPT=$@

# if [[ -n $MV_EXTRA_PATCH_SETS && "$CANONIC_BUILD" != "Y" && "$rARCH" == "amd64" ]]; then
# # patches from    "-1  -2  -3"
# rEXTRA_PATCH_SETS="-1"
# export OTHER_BUILD_OPTIONS="INCLUDE_ICCPD=y"
# fi

#==============================================================================
SONIC_BUILD_SH_CMD="./sonic_build_script.sh $rBRANCH $rBUILD_PLATFORM $rBUILD_PLATFORM_ARCH \
 $rEXTRA_PATCH_SETS $rBUILD_RPC $rBUILD_SAISERVER $rBUILD_NO_CACHE $rCOMMIT_ID \
 $rPATCH_SCRIPT_PATH $rSAI_VER $rSAI_DEB $rEXTRA_OPT"

echo "========================================================================="
echo "<< Release build-configuration"
echo "SONIC_BRANCH=$SONIC_BRANCH"
echo "SONIC_COMMIT_ID=$SONIC_COMMIT_ID"
echo "MRVLLIBSAI_VER=$MRVLLIBSAI_VER"
echo "CANONIC_BUILD=$CANONIC_BUILD"
echo "MV_EXTRA_PATCH_SETS=$rEXTRA_PATCH_SETS"
echo ">>"
echo "Run in directory `pwd`"
echo "$SONIC_BUILD_SH_CMD"
echo "-------------------------------------------------------------------------"
$SONIC_BUILD_SH_CMD
