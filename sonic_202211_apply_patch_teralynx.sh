#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation


#
# patch script for TL10 X86 board
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="5500dc47d1178555a4807b566b0ff29bc3844f28"

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

# Path for 202211 patches
WGET_PATH="https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/tl_03/files/202211/"

# Patches
SERIES="0001-marvell-x86-syncd-docker-TL10-and-SAI-inclusions.patch
        0002-marvell-Backport-of-master-PR-14589-to-202211-branch.patch
        0003-marvell-backport-master-PR-12653-innovium-platform-f.patch
        0004-marvell-midstone-Compilation-Error-in-master-branch-.patch
        0005-marvell-platform-and-hwsku-files-for-wistron-and-cel.patch
        0006-marvell-bullseye-migration-for-innovium.patch
	0007-marvell-teralynx-Use-the-archive-repo-for-Buster-186.patch
	0008-marvell-teralynx-Add-SDK-dependent-python-packages-1.patch"

PATCHES=""

# Sub module patches
declare -a SUB_PATCHES=(SP1 SP2)
declare -A SP1=([NAME]="0001-Marvell-teralynx-generate_dump.patch" [DIR]="src/sonic-utilities")
declare -A SP2=([NAME]="0001-kempld-patches-for-5.10.patch" [DIR]="src/sonic-linux-kernel")

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

    log "<<FOR INTEL>> make configure PLATFORM=innovium"
    log "make target/sonic-innovium.bin"
}

apply_patch_series()
{
    for patch in $SERIES
    do
        echo $patch
        pushd patches
        wget -c --timeout=2 $WGET_PATH/$patch
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
        wget -c --timeout=2 $WGET_PATH/$patch
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
        wget -c --timeout=2 $WGET_PATH/${!patch}
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
    wget -c --timeout=2 https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/tl_03/files/mrvl_sonic_hwsku_dbmvtx9180.tgz
    wget -c --timeout=2 https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/tl_03/files/mrvl_sonic_platform_dbmvtx9180.tgz

    rm -fr device/marvell/x86_64-marvell_dbmvtx9180-r0 || true
    rm -fr platform/innovium/sonic-platform-modules-marvell || true
    tar -C device/marvell/ -xzf mrvl_sonic_hwsku_dbmvtx9180.tgz
    tar -C platform/innovium/ -xzf mrvl_sonic_platform_dbmvtx9180.tgz
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
