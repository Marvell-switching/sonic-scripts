#!/bin/bash

SONIC_TARGET_ARCH="${SONIC_TARGET_ARCH:-$(uname -m)}"
  case "$SONIC_TARGET_ARCH" in
    x86_64|i386|i686)  rARCH="amd64"  ;;
    aarch64|armv8l)    rARCH="arm64"  ;;
    armv7l|armhf)      rARCH="armhf"  ;;
    *)        echo "ERROR: build-target-arch is unknown" ;;
  esac

rBUILD_PLATFORM_ARCH="-a $rARCH"
rBRANCH="-b 202511"
rBUILD_PLATFORM="-p marvell-prestera"
rBUILD_RPC="-r"
#rBUILD_SAISERVER="-s"
rBUILD_NO_CACHE="--no-cache"
rCOMMIT_ID="-c 922fae553"
SAI_VER=1.17.1-21

rPATCH_SCRIPT_PATH="--patch_script `pwd`/marvell_sonic_patch_script.sh"
#rSAI_DEB="--SAI `pwd`/mrvllibsai_1.17.1-21_${rARCH}.deb"
#rSAI_DEB="--SAI <URL>/mrvllibsai_1.17.1-21_${rARCH}.deb"

if [ -z "${rSAI_DEB}" ]; then
    rSAI_VER="--SAI_VER ${SAI_VER}"
    if [ -f "./mrvllibsai_${SAI_VER}_${rARCH}.deb" ]; then
        rSAI_DEB="--SAI `pwd`/mrvllibsai_${SAI_VER}_${rARCH}.deb"
    fi
fi

rEXTRA_OPT=$@

if [ "$rARCH" == "amd64" ]; then
# patches from    "-1  -2  -3"
rEXTRA_PATCH_SETS="-1"
fi
#export OTHER_BUILD_OPTIONS="INCLUDE_ICCPD=y"

#==============================================================================
SONIC_BUILD_SH_CMD="./sonic_build_script.sh $rBRANCH $rBUILD_PLATFORM $rBUILD_PLATFORM_ARCH \
 $rEXTRA_PATCH_SETS $rBUILD_RPC $rBUILD_SAISERVER $rBUILD_NO_CACHE $rCOMMIT_ID \
 $rPATCH_SCRIPT_PATH $rSAI_VER $rSAI_DEB $rEXTRA_OPT"

echo "========================================================================="
echo "Run in directory `pwd`"
echo "$SONIC_BUILD_SH_CMD"
echo "-------------------------------------------------------------------------"
$SONIC_BUILD_SH_CMD
