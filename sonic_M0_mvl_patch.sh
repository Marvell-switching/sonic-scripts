#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation

set -e

#
# patch script for ARM32/ARMHF M0 board
#

#
# CONFIGURATIONS:-
#

SONIC_MASTER_COMMIT="5ab300b62669e65c3095ac50a020f970c0337e66"

declare -a PATCHES=(P1 P2)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"

declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="" [URL]="$url" [PREREQ]="" [POSTREQ]="")
declare -A P2=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="apply_buster_kernel" )

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`
SCRIPT_DIR=$(dirname $0)

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log ""
    log ""
    log "STEPS TO BUILD:"
    log "git clone https://github.com/Azure/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_MASTER_COMMIT"
    log "git checkout -b mrvl"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "make configure PLATFORM=marvell-armhf PLATFORM_ARCH=armhf"
    log "make all"
    log ""
    log ""
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

inband_mgmt_fix()
{
    # WA to restart networking for inband mgmt
    sed -i '/build_version/i \
/bin/sh /etc/inband_mgmt' files/image_config/platform/rc.local

    sed -i '/platform rc.local/i \
sudo cp $IMAGE_CONFIGS/platform/inband_mgmt $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2

    rm -f files/image_config/platform/inband_mgmt
    echo "#inband_mgmt" > files/image_config/platform/inband_mgmt
sed -i '$ a \
inband_mgmt(){\
 rmmod i2c-dev \
 rmmod i2c_mux_gpio \
 rmmod i2c_mv64xxx \
 modprobe i2c_mv64xxx \
 modprobe i2c-dev \
 modprobe i2c_mux_gpio \
 sleep 60 \
 while :; do\
   ip -br link show eth0 2> /dev/null\
   if [ $? -eq 0 ]; then\
       ip address show eth0 | grep -qw "inet" 2>/dev/null\
       if [ $? -ne 0 ]; then\
           ifconfig eth0 down\
           systemctl restart networking\
       fi\
       sleep 120\
   else\
     sleep 3\
   fi\
 done\
}\
(inband_mgmt > /dev/null)&' files/image_config/platform/inband_mgmt

   # Download hwsku
   wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_sonic_m0_hwsku.tgz
   tar -C device/marvell/armhf-marvell_et6448m_52x-r0/ -xzf mrvl_sonic_m0_hwsku.tgz

}

apply_buster_kernel()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_kernel_4.19.152.patch
    patch -p1 --dry-run < ./armhf_kernel_4.19.152.patch
    echo "Patching 4.19.152 armhf"
    patch -p1 < ./armhf_kernel_4.19.152.patch

    # Adding  DTS for platform ET6448M and IPD6448M
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch
    patch -p1 --dry-run < ./armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch
    echo "Patching DTS for platform ET6448M and IPD6448M"
    patch -p1 < ./armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch

}

bug_fixes()
{
    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-py-common/sonic_py_common/device_info.py

    # snmp subagent
    echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2

    # Disable Telemetry
    sed -i 's/INCLUDE_MGMT_FRAMEWORK = y/INCLUDE_MGMT_FRAMEWORK = n/g' rules/config
    sed -i 's/INCLUDE_SYSTEM_TELEMETRY = y/INCLUDE_SYSTEM_TELEMETRY = n/g' rules/config

    # Add entropy
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
python /etc/ent.py &' files/image_config/platform/rc.local

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

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_MASTER_COMMIT" ]; then
        log "Checkout sonic-buildimage commit as below to proceed"
        log "git checkout ${SONIC_MASTER_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    inband_mgmt_fix

    enable_sdk_shell

    bug_fixes

}

main $@
