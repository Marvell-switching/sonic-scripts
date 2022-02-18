#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation

#
# Create patches 
#

CUR_DIR=$(basename `pwd`)

# TIPS...
# 1) Use 'git add -N <>" to add any new untracked file
# 2) add any new dir in below list of diffs.

# Patches
declare -a PATCHES=(P1 P2 P3 P4)
declare -A P1=([NAME]="generic_fixes_or_wa.patch" [DIR]="dockers/ files/ installer/ rules/")
declare -A P2=([NAME]="marvell_arm64.patch" [DIR]="platform/marvell-arm64/")
declare -A P3=([NAME]="marvell_x86.patch" [DIR]="platform/marvell/")
declare -A P4=([NAME]="sonic_config_engine.patch" [DIR]="src/sonic-config-engine/")

# Sub module patches
declare -a SUB_PATCHES=(SP1 SP2 SP3 SP4)
declare -A SP1=([NAME]="sonic_swss.patch" [DIR]="src/sonic-swss")
declare -A SP2=([NAME]="sonic_sairedis.patch" [DIR]="src/sonic-sairedis")
declare -A SP3=([NAME]="sonic_utilities.patch" [DIR]="src/sonic-utilities")
declare -A SP4=([NAME]="sonic_linux_kernel.patch" [DIR]="src/sonic-linux-kernel")


create_patches()
{
    for P in ${PATCHES[*]}
    do
        patch=${P}[NAME]
        dir=${P}[DIR]
        echo "${!patch} ${!dir}"
	    git diff ${!dir} > patches/${!patch}
    done
}

create_submodule_patches()
{
    CWD=`pwd`
    for SP in ${SUB_PATCHES[*]}
    do
        patch=${SP}[NAME]
        dir=${SP}[DIR]
        echo "${!patch} ${!dir} $CWD"
        pushd ${!dir}
        git diff > $CWD/patches/${!patch}
        popd
    done
}

main()
{
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        echo "ERROR: Need to be at sonic-builimage git clone path"
        exit
    fi

    [ -d patches ] || mkdir patches

    echo -e "\nCollecting diff"
    create_patches

    # git submodule patches

    echo -e "\nCollecting diff from submodules"
    create_submodule_patches
}

main $@
