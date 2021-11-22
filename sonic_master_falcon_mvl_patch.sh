#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation


#
# patch script for ARM64 Falcon board
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="d0c73b050d860162a2c572a907c3b46595caed4c"

declare -a PATCHES=(P1)

url="https://github.com/Azure"

declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="50" [URL]="https://github.com/Marvell-OpenNOS/" [PREREQ]="" [POSTREQ]="")

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/Azure/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
}

enable_sdk_shell()
{
    #PR 5519
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/shell_buildimage.patch
    patch -p1 < shell_buildimage.patch

    #PR 1454
    pushd src/sonic-swss
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/shell_swss.patch
    patch -p1 < shell_swss.patch
    popd

    #PR 1146
    pushd src/sonic-utilities
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/shell_utilities.patch
    patch -p1 < shell_utilities.patch
    popd
}

apply_patches()
{
    CWD=`pwd`
    #URL_CMD="wget $url/$module/pull/$pr.diff"
    for f in ${PATCHES[*]}
    do
        P_NAME=${f}[NAME]
        log "INFO: ${!P_NAME} ... "
        P_DIR=${f}[DIR]
        log "CMD: cd ${!P_DIR}"
        cd ${!P_DIR}
        P_PRS=${f}[PR]
        P_URL=${f}[URL]
        P_PREREQ=${f}[PREREQ]
        P_POSTREQ=${f}[POSTREQ]

        if [ -n "${!P_PREREQ}" ]
        then
            log "INFO calling prereq ${!P_PREREQ}"
            eval ${!P_PREREQ}
        fi

        for p in ${!P_PRS}
        do
            log "INFO: URL ${!P_URL}/${!P_NAME}/pull/${p}.diff"
            rm -f ${p}.diff || true
            wget "${!P_URL}/${!P_NAME}/pull/${p}.diff"
            if [ -f ${p}.diff ]
            then
                log "INFO: patch -p1 < ${p}.diff"
                patch -p1 -f --dry-run < ${p}.diff
                if [ $? -eq 0 ]; then
                    log "INFO: Applying patch"
                    patch -p1 < ${p}.diff
                else
                    log "ERROR: Patch ${!P_NAME} ${p} has failures, try manually"
                fi
                rm -f ${p}.diff
            else
                log "ERROR: Could not download patch ${!P_NAME} ${p}.diff"
            fi
        done

        if [ -n "${!P_POSTREQ}" ]
        then
            log "INFO calling post script ${!P_POSTREQ}"
            eval ${!P_POSTREQ}
        fi
        cd ${CWD}
    done
}

create_temp_rclocal_patch()
{
cat <<EOF > /tmp/rclocal_fix
echo "Marvell: Executing Workarounds !!!!"

echo "Switch Mac Address Update"
MAC_ADDR=\`ip link show eth0 | grep ether | awk '{print \$2}'\`
find /usr/share/sonic/device/*db98cx* -name profile.ini | xargs sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g"
EOF

}

bug_fixes()
{
    pushd src/sonic-linux-kernel
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/linux-ARM64-and-ARMHF-build-changes.patch
    patch -p1 --dry-run < ./linux-ARM64-and-ARMHF-build-changes.patch
    patch -p1 < ./linux-ARM64-and-ARMHF-build-changes.patch
    popd

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/build_fix.patch
    patch -p1 --dry-run < ./build_fix.patch
    patch -p1 < ./build_fix.patch

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/syncd_buster.patch
    patch -p1 --dry-run < ./syncd_buster.patch
    patch -p1 < ./syncd_buster.patch

    #redis workaround to increase lua-time-limit to 20000ms
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/redis_wa.patch
    patch -p1 < redis_wa.patch

    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-py-common/sonic_py_common/device_info.py

    # snmp subagent
    #echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2

    #1 Disable Mgmt Framework and Telemetry
    sed -i 's/INCLUDE_MGMT_FRAMEWORK = y/INCLUDE_MGMT_FRAMEWORK = n/g' rules/config
    sed '/INCLUDE_SYSTEM_TELEMETRY/d' platform/marvell-arm64/rules.mk

    #2 TODO: Add Entropy workaround for ARM64
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
        sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
        python /etc/ent.py &' files/image_config/platform/rc.local

    #3 update mac in profile.ini
    create_temp_rclocal_patch
    sed '16r /tmp/rclocal_fix' < files/image_config/platform/rc.local > files/image_config/platform/rc.local_new
    mv files/image_config/platform/rc.local files/image_config/platform/rc.local_orig
    mv files/image_config/platform/rc.local_new files/image_config/platform/rc.local
    chmod a+rwx files/image_config/platform/rc.local

    #4 Watchdog/select Timeout  workaround
    sed -i 's/#define SELECT_TIMEOUT 1000/#define SELECT_TIMEOUT 1999999/g' src/sonic-swss/orchagent/orchdaemon.cpp
    sed -i 's/(60\*1000)/(1999999)/g' src/sonic-sairedis/lib/inc/sairedis.h

    #5 copp configuration for jumbo
    sed -i 's/"cir":"600",/"cir":"6000",/g' files/image_config/copp/copp_cfg.j2
    sed -i 's/"cbs":"600",/"cbs":"6000",/g' files/image_config/copp/copp_cfg.j2

    # Download hwsku
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_sonic_falcon_hwsku.tgz
    rm -fr device/marvell/x86_64-marvell_db98cx8580_32cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8580_32cd-r0  || true
    rm -fr device/marvell/x86_64-marvell_db98cx8540_16cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8540_16cd-r0  || true
    tar -C device/marvell/ -xzf mrvl_sonic_falcon_hwsku.tgz
    cp -dr device/marvell/arm64-marvell_db98cx8580_32cd-r0 device/marvell/x86_64-marvell_db98cx8580_32cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8540_16cd-r0 device/marvell/x86_64-marvell_db98cx8540_16cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8514_10cc-r0 device/marvell/x86_64-marvell_db98cx8514_10cc-r0
    rm device/marvell/arm64-marvell_db98cx8580_32cd-r0/plugins/x86_64_sfputil.py
    rm device/marvell/arm64-marvell_db98cx8540_16cd-r0/plugins/x86_64_sfputil.py
    rm device/marvell/arm64-marvell_db98cx8514_10cc-r0/plugins/x86_64_sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8580_32cd-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8580_32cd-r0/plugins/sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8540_16cd-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8540_16cd-r0/plugins/sfputil.py
    mv device/marvell/x86_64-marvell_db98cx8514_10cc-r0/plugins/x86_64_sfputil.py device/marvell/x86_64-marvell_db98cx8514_10cc-r0/plugins/sfputil.py

    #8 Add Falcon module  
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/falcon_modules.patch
    patch -p1 < falcon_modules.patch

    #9 TODO: Intel USB access
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_usb_install_slow.patch
    patch -p1 < sonic_usb_install_slow.patch

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
        log "Checkout Dec14 sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    enable_sdk_shell

    bug_fixes
}

main $@
