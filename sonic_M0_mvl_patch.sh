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

SONIC_MASTER_JUN30_COMMIT="96fedf1ae9ebcc6604daced6b7dd577eaeb26883"

declare -a PATCHES=(P1 P2 P3 P4 P5 P6 P7 P8 P9)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"

declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3687 5500 6040" [URL]="$url" [PREREQ]="" [POSTREQ]="buildimage_post_script")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1325 1273 1369 1407 " [URL]="$url" [PREREQ]="" [POSTREQ]="swss_post_script" )
declare -A P3=( [NAME]=sonic-swss-common [DIR]=src/sonic-swss-common [PR]="" [URL]="$url" [PREREQ]="" )
declare -A P4=( [NAME]=sonic-mgmt-framework [DIR]=src/sonic-mgmt-framework [PR]="" [URL]="$url" [PREREQ]="" )
declare -A P5=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="apply_buster_kernel" )
declare -A P6=( [NAME]=sonic-platform-common [DIR]=src/sonic-platform-common [PR]="" [URL]="$url" [PREREQ]="" )
declare -A P7=( [NAME]=sonic-snmpagent [DIR]=src/sonic-snmpagent [PR]="134" [URL]="$url" [PREREQ]="" )
declare -A P8=( [NAME]=sonic-sairedis [DIR]=src/sonic-sairedis [PR]="643" [URL]="$url" [PREREQ]="" )
declare -A P9=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]="" [URL]="$url" [PREREQ]="" [POSTREQ]="utilities_post_script")

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
    log "git checkout $SONIC_MASTER_JUN30_COMMIT"
    log "git checkout -b mrvl"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "make configure PLATFORM=marvell-armhf PLATFORM_ARCH=armhf"
    log "make all"
    log ""
    log ""
}
swss_post_script()
{
    #PR 1454
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/shell_swss.patch
    patch -p1 < shell_swss.patch
}

buildimage_post_script()
{
    #PR 5519
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/shell_buildimage.patch
    patch -p1 < shell_buildimage.patch
    #PR 5252
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/5252_ebtables.patch
    patch -p1 < 5252_ebtables.patch
    rm files/image_config/ebtables/ebtables.filter

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm_redis_storage.patch
    patch -p1 < arm_redis_storage.patch

    #redis workaround to increase lua-time-limit to 20000ms
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/redis_wa.patch
    patch -p1 < redis_wa.patch
}

utilities_post_script()
{
    #PR 1146
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/shell_utilities.patch
    patch -p1 < shell_utilities.patch
    #PR 1140
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/1140_portstat.patch
    patch -p1 < 1140_portstat.patch
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

misc_workarounds()
{
    # Workarounds for Build machine
    # Change docker spawn wait time to 4 sec
    #cd sonic-buildimage
    #sed -i 's/sleep 1/sleep 4/g' Makefile.work

    # Disable Telemetry
    sed -i 's/ENABLE_MGMT_FRAMEWORK = y/ENABLE_MGMT_FRAMEWORK = N/g' rules/config

    # Add entropy
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
python /etc/ent.py &' files/image_config/platform/rc.local

   # enable sflow
   #sed -i 's/("sflow", "disabled")/("sflow", "enabled")/g' files/build_templates/init_cfg.json.j2

   # Starting teamd after syncd. (PR #4016)
   #sed -i 's/After=updategraph.service/After=updategraph.service syncd.service/g' files/build_templates/per_namespace/teamd.service.j2
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
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_kernel_4.19.67.patch

    patch -p1 --dry-run < ./armhf_kernel_4.19.67.patch
    echo "Patching 4.19.67 armhf"
    patch -p1 < ./armhf_kernel_4.19.67.patch

    # Adding  DTS for platform ET6448M and IPD6448M
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch
    patch -p1 --dry-run < ./armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch
    echo "Patching DTS for platform ET6448M and IPD6448M"
    patch -p1 < ./armhf_DTS-files-for-platform-ET6448M-and-IPD6448M.patch

}

build_kernel_buster()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_build_kernel_4.19.67_jun09.patch
    patch -p1 --dry-run < ./armhf_build_kernel_4.19.67_jun09.patch
    echo "Patching 4.19.67 build rules"
    patch -p1 < ./armhf_build_kernel_4.19.67_jun09.patch
}

master_armhf_fix()
{

    # sonic slave docker
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_slave_docker.patch
    patch -p1 --dry-run < ./sonic_slave_docker.patch
    echo "SONIC slave build"
    patch -p1 < ./sonic_slave_docker.patch
    
    # sonic base  docker
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_base_docker.patch
    patch -p1 --dry-run < ./sonic_base_docker.patch
    echo "SONIC base build"
    patch -p1 < ./sonic_base_docker.patch

    # Curl patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/curl_insecure_wa.patch
    patch -p1 --dry-run < ./curl_insecure_wa.patch
    echo "Curl insecure download"
    patch -p1 < ./curl_insecure_wa.patch

    # libyang patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/libyang_wa.patch
    patch -p1 --dry-run < ./libyang_wa.patch
    echo "Libyang fix test"
    patch -p1 < ./libyang_wa.patch

    # sonic_yang patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_yang_wa_jun09.patch
    patch -p1 --dry-run < ./sonic_yang_wa_jun09.patch
    echo "sonic-yang fix test"
    patch -p1 < ./sonic_yang_wa_jun09.patch

    # reboot syslog patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/reboot_syslog.patch
    patch -p1 --dry-run < ./reboot_syslog.patch
    echo "reboot_syslog fix test"
    patch -p1 < ./reboot_syslog.patch

    # wheel
    sed -i '/keep pip installed/i \
sudo https_proxy=$https_proxy LANG=C chroot $FILESYSTEM_ROOT pip install wheel' build_debian.sh

    # Update SAI 1.6.3
    sed -i 's/1.5.1/1.6.3/g' platform/marvell-armhf/sai.mk

    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-config-engine/sonic_device_util.py

    # Fancontrol
    sed -i '/fancontrol.pid/i \
/bin/cp -f /usr/share/sonic/platform/fancontrol /etc/' dockers/docker-platform-monitor/docker_init.sh

    # snmp subagent
    echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2

    # Update redis version
    #sed -i 's/redis-tools=5:6.0.5-1~bpo10+1/redis-tools=5:6.0.8-1~bpo10+1/g' dockers/docker-base-buster/Dockerfile.j2
    #sed -i 's/redis-server=5:6.0.5-1~bpo10+1/redis-server=5:6.0.8-1~bpo10+1/g' dockers/docker-database/Dockerfile.j2

    # sonic_generate_dump patch
    pushd src/sonic-utilities
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_generate_dump.patch
    patch -p1 --dry-run < ./sonic_generate_dump.patch
    patch -p1 < ./sonic_generate_dump.patch

    # cli performance improvement patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/cli_perf_improvement.patch
    patch -p1 --dry-run < ./cli_perf_improvement.patch
    patch -p1 < ./cli_perf_improvement.patch
    popd
}

update_sai_deb()
{
    # Using sai deb from xps branch
    sed -i 's/mrvllibsai_/mrvllibsai_xps_202006_/g' platform/marvell-armhf/sai.mk
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_MASTER_JUN30_COMMIT" ]; then
        log "Checkout sonic-buildimage commit as below to proceed"
        log "git checkout ${SONIC_MASTER_JUN30_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    misc_workarounds

    inband_mgmt_fix

    build_kernel_buster

    master_armhf_fix

    update_sai_deb
}

main $@
