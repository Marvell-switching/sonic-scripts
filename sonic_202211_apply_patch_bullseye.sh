#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation


#
# patch script for ARM64 Falcon and AC5X board
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="cd6636d4d25894236b76735aae9a6e582bb8a8b2"

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

# Path for 202211 patches
WGET_PATH="https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/202211_02/files/202211/"

# Patches
SERIES="0001-Add-support-for-Nokia-7215-A1-platform-13795.patch
    0002-Support-for-lazy-install-sdk-drivers.patch
    0003-marvell-arm64-Add-platform-support-for-rd98DX35xx.patch
    0004-marvell-arm64-Add-platform-support-db98cx8540.patch
    0005-marvell-arm64-Add-platform-support-db98cx8580.patch
    0006-marvell-arm64-Add-platform-support-rd98DX35xx_ext.patch
    0008-Unified-sdk-driver-changes.patch
    0009-marvell-arm64-Add-platform-support-for-CN9131.patch"

PATCHES=""

# Sub module patches
declare -a SUB_PATCHES=(SP1 SP2 SP3 SP4 SP5 SP6 SP7 SP8)
declare -A SP1=([NAME]="0001-Marvell-pfc-detect-change.patch" [DIR]="src/sonic-swss")
declare -A SP2=([NAME]="0001-Marvell-generate_dump-utility.patch" [DIR]="src/sonic-utilities")
declare -A SP3=([NAME]="0002-Use-kexec_load-syscall-for-stability.patch" [DIR]="src/sonic-utilities")
declare -A SP4=([NAME]="0001-SAI-switch-create-timeout-WA.patch" [DIR]="src/sonic-sairedis")
declare -A SP5=([NAME]="0001-Add-support-for-98DX35xx-and-98CX85xx-platform-311.patch" [DIR]="src/sonic-linux-kernel")
declare -A SP6=([NAME]="0002-ac5x-8G-DDR-support-changes.patch" [DIR]="src/sonic-linux-kernel")
declare -A SP7=([NAME]="0003-marvell-Add-support-for-CN913X-DB-Comexpress.patch" [DIR]="src/sonic-linux-kernel")
declare -A SP8=([NAME]="0004-arm64-Enable-CONFIG_KEXEC_FILE.patch" [DIR]="src/sonic-linux-kernel")

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/sonic-net/sonic-buildimage.git -b 202211"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>"
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
}

apply_patch_series()
{
    for patch in $SERIES
    do
        echo $patch
        pushd patches
        wget -c $WGET_PATH/$patch
        popd
        git am patches/$patch
        if [ $? -ne 0 ]; then
            log "ERROR: Failed to apply patch $patch"
            exit 1
        fi
    done
}

apply_patches()
{
    for patch in $PATCHES
    do
	echo $patch	
    	pushd patches
    	wget -c $WGET_PATH/$patch
        popd
	    patch -p1 < patches/$patch
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch $patch"
            exit 1
    	fi
    done
}

apply_submodule_patches()
{
    CWD=`pwd`
    for SP in ${SUB_PATCHES[*]}
    do
	patch=${SP}[NAME]
	dir=${SP}[DIR]
	echo "${!patch}"
    	pushd patches
    	wget -c $WGET_PATH/${!patch}
        popd
	    pushd ${!dir}
        git am $CWD/patches/${!patch}
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch ${!patch}"
            exit 1
    	fi
	popd
    done
}

apply_hwsku_changes()
{
    # Download hwsku
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/202211_02/files/mrvl_sonic_hwsku_ezb.tgz

    rm -fr device/marvell/x86_64-marvell_db98cx8580_32cd-r0 || true
    rm -rf device/marvell/x86_64-marvell_slm5401_54x-r0     || true
    rm -fr device/marvell/arm64-marvell_db98cx8580_32cd-r0  || true
    rm -fr device/marvell/x86_64-marvell_db98cx8540_16cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8540_16cd-r0  || true
    rm -fr device/marvell/armhf-marvell_et6448m_52x-r0      || true
    tar -C device/marvell/ -xzf mrvl_sonic_hwsku_ezb.tgz
    cp -dr device/marvell/arm64-marvell_db98cx8580_32cd-r0 device/marvell/x86_64-marvell_db98cx8580_32cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8540_16cd-r0 device/marvell/x86_64-marvell_db98cx8540_16cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8514_10cc-r0 device/marvell/x86_64-marvell_db98cx8514_10cc-r0
    rm device/marvell/arm64-marvell_db98cx8580_32cd-r0/plugins/x86_64_sfputil.py
    rm device/marvell/arm64-marvell_db98cx8540_16cd-r0/plugins/x86_64_sfputil.py
    rm device/marvell/arm64-marvell_db98cx8514_10cc-r0/plugins/x86_64_sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8580_32cd-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8580_32cd-r0/plugins/sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8540_16cd-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8540_16cd-r0/plugins/sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8514_10cc-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8514_10cc-r0/plugins/sfputil.py
    echo "marvell" > device/marvell/x86_64-marvell_db98cx8514_10cc-r0/platform_asic
    echo "marvell" > device/marvell/x86_64-marvell_db98cx8540_16cd-r0/platform_asic
    echo "marvell" > device/marvell/x86_64-marvell_db98cx8580_32cd-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_db98cx8514_10cc-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_db98cx8540_16cd-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_db98cx8580_32cd-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_rd98DX35xx-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_rd98DX35xx_ext-r0/platform_asic
    echo "marvell-arm64" > device/marvell/arm64-marvell_rd98DX35xx_cn9131-r0/platform_asic
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_COMMIT" ]; then
        log "Checkout sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}
    [ -d patches ] || mkdir patches

    # Apply patch series
    apply_patch_series
    # Apply patches
    apply_patches
    # Apply submodule patches
    apply_submodule_patches
    # Apply hwsku changes
    apply_hwsku_changes
}

main $@
