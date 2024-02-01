#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation


#
# patch script for ARM64 Falcon and AC5X board
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="6b8549c3bb4efa2fdf59c217c863223694ba377b"

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

# Path for 202311 patches
WGET_PATH="https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/202311_01/files/202311/"

# Patches
SERIES="0001-Redis-timeout-WA.patch"

PATCHES=""

# Sub module patches
declare -a SUB_PATCHES=(SP1 SP2 SP3 SP4)
declare -A SP1=([NAME]="0001-SAI-switch-create-timeout-WA.patch" [DIR]="src/sonic-sairedis")
declare -A SP2=([NAME]="0001-marvell-ac5-Support-boards-with-more-that-4G-DDR.patch" [DIR]="src/sonic-linux-kernel")
declare -A SP3=([NAME]="0002-Marvell-arm64-Enable-CONFIG_ARM_SMC_WATCHDOG.patch" [DIR]="src/sonic-linux-kernel")
declare -A SP4=([NAME]="0003-mvpp2-clear-BM-pool-before-initialization.patch" [DIR]="src/sonic-linux-kernel")

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/sonic-net/sonic-buildimage.git -b 202311"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>"
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR ARM64>> make target/sonic-marvell-arm64.bin"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "<<FOR INTEL>> make target/sonic-marvell.bin"
}

apply_patch_series()
{
    for patch in $SERIES
    do
        echo $patch
        pushd patches
        wget --timeout=2 -c $WGET_PATH/$patch
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
    	wget -timeout=2 -c $WGET_PATH/$patch
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
    	wget --timeout=2 -c $WGET_PATH/${!patch}
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
    wget --timeout=2 -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/202311_01/files/mrvl_sonic_hwsku_ezb.tgz

    tar -C device/marvell/ -xzf mrvl_sonic_hwsku_ezb.tgz
    echo "marvell-arm64" > device/marvell/arm64-marvell_rd98DX35xx-r0/platform_asic
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
