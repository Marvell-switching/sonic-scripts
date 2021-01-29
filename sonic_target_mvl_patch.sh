#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation


#
# patch script for ARM64 Falcon board
#

#
# CONFIGURATIONS:-
#

SONIC_MASTER_JUN30_COMMIT="96fedf1ae9ebcc6604daced6b7dd577eaeb26883"

declare -a PATCHES=(P1 P2 P3 P4 P5 P6 P7 P8)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"


declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3687 5500 5733 6040" [URL]="$url" [PREREQ]="" [POSTREQ]="buildimage_post_script")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1325 1273 1369 1407" [URL]="$url" [PREREQ]="" [POSTREQ]="swss_post_script")
declare -A P3=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]="" [URL]="$url" [PREREQ]="" [POSTREQ]="utilities_post_script")
declare -A P4=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="apply_buster_kernel" )
declare -A P5=( [NAME]=sonic-snmpagent [DIR]=src/sonic-snmpagent [PR]="134" [URL]="$url" [PREREQ]="" )
declare -A P6=( [NAME]=sonic-sairedis [DIR]=src/sonic-sairedis [PR]="643" [URL]="$url" [PREREQ]="" )
declare -A P7=( [NAME]=sonic-swss-common [DIR]=src/sonic-swss-common [PR]="391" [URL]="$url" [PREREQ]="" )
declare -A P8=( [NAME]=sonic-buildimage [DIR]=. [PR]="14 15 16 17 18 19 20 21 22" [URL]="https://github.com/Marvell-OpenNOS" [PREREQ]="" [POSTREQ]="")
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
    log "git checkout $SONIC_MASTER_JUN30_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
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

installer_patch()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_falcon_dec14_sonic_util.patch
    patch -p1 < mrvl_falcon_dec14_sonic_util.patch
    rm mrvl_falcon_dec14_sonic_util.patch
}

apply_buster_kernel()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/linux-ARM64-and-ARMHF-build-changes.patch

    patch -p1 --dry-run < ./linux-ARM64-and-ARMHF-build-changes.patch
    echo "Patching 4.19.67 arm changes"
    patch -p1 < ./linux-ARM64-and-ARMHF-build-changes.patch
 
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm64_TG48MP_DTS_and_Kernel_config.patch

    patch -p1 --dry-run < ./arm64_TG48MP_DTS_and_Kernel_config.patch
    echo "Patching tg48mp kernel changes"
    patch -p1 < ./arm64_TG48MP_DTS_and_Kernel_config.patch
    
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm64_TG4810M_DTS_and_Kernel_config.patch

    patch -p1 --dry-run < ./arm64_TG4810M_DTS_and_Kernel_config.patch
    echo "Patching tg4810m kernel changes"
    patch -p1 < ./arm64_TG4810M_DTS_and_Kernel_config.patch

}

build_kernel_buster()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm64_build_kernel_4.19.67.patch
    patch -p1 --dry-run < ./arm64_build_kernel_4.19.67.patch
    echo "Patching 4.19.67 build rules"
    patch -p1 < ./arm64_build_kernel_4.19.67.patch
}

build_arm64_falcon()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_arm64_build_patch.patch
    patch -p1 --dry-run < ./mrvl_arm64_build_patch.patch
    echo "Patching mrvl_arm64_build_patch.patch"
    patch -p1 < ./mrvl_arm64_build_patch.patch
}

master_sonic_fix()
{

   # # sonic slave docker
   # wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_slave_docker.patch
   # patch -p1 --dry-run < ./sonic_slave_docker.patch
   # echo "SONIC slave build"
   # patch -p1 < ./sonic_slave_docker.patch

   # # Curl patch
   # wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/curl_insecure_wa.patch
   # patch -p1 --dry-run < ./curl_insecure_wa.patch
   # echo "Curl insecure download"
   # patch -p1 < ./curl_insecure_wa.patch

   # # libyang patch
   # wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/libyang_wa.patch
   # patch -p1 --dry-run < ./libyang_wa.patch
   # echo "Libyang fix test"
   # patch -p1 < ./libyang_wa.patch

   # # sonic_yang patch
   # wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_yang_wa_jun09.patch
   # patch -p1 --dry-run < ./sonic_yang_wa_jun09.patch
   # echo "sonic-yang fix test"
   # patch -p1 < ./sonic_yang_wa_jun09.patch

    # netlink rxBuf Size to 3M patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/netlink_rxBufSize.patch
    patch -p1 --dry-run < ./netlink_rxBufSize.patch
    patch -p1 < ./netlink_rxBufSize.patch

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
    sed -i 's/1.5.1/1.6.3/g' platform/marvell-arm64/sai.mk
    sed -i 's/1.5.1/1.6.3/g' platform/marvell/sai.mk

    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-config-engine/sonic_device_util.py

    # Fancontrol
    sed -i '/fancontrol.pid/i \
/bin/cp -f /usr/share/sonic/platform/fancontrol /etc/' dockers/docker-platform-monitor/docker_init.sh

    # snmp subagent
    echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2

    # enable sflow
    #sed -i 's/("sflow", "disabled")/("sflow", "enabled")/g' files/build_templates/init_cfg.json.j2

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
   
    # Starting teamd after syncd. issue(4015)
    sed -i 's/After=updategraph.service/After=updategraph.service syncd.service/g' files/build_templates/per_namespace/teamd.service.j2
    #architecture fix
    sed -i 's/Architecture: amd64/Architecture: any/g' src/sonic-mgmt-common/debian/control
    #disable management frmwork
    sed -i 's/ENABLE_MGMT_FRAMEWORK = y/ENABLE_MGMT_FRAMEWORK = N/g' rules/config
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
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8580_16cd-r0/db98cx8580_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8580_16cd-r0/db98cx8580_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/profile.ini
find /usr/share/sonic/device/*db98cx* -name profile.ini | xargs sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g"
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-delta_tg48m_poe-r0/delta_tg48m_poe/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-delta_tg4810m-r0/delta_tg4810m/profile.ini

EOF

}

misc_workarounds()
{
    #1 Disable Telemetry
    sed -i 's/ENABLE_SYSTEM_TELEMETRY = y/ENABLE_SYSTEM_TELEMETRY = N/g' rules/config

    #2 TODO: Add Entropy workaround for ARM64
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
        sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
        python /etc/ent.py &' files/image_config/platform/rc.local


    #3 Add ipv4/ipv6 arp gc_thresh
    create_temp_rclocal_patch
    sed '16r /tmp/rclocal_fix' < files/image_config/platform/rc.local > files/image_config/platform/rc.local_new
    mv files/image_config/platform/rc.local files/image_config/platform/rc.local_orig
    mv files/image_config/platform/rc.local_new files/image_config/platform/rc.local
    chmod a+rwx files/image_config/platform/rc.local

    #4 Watchdog/select Timeout  workaround
    #sed -i 's/(60\*1000)/(500\*1000)/g' src/sonic-sairedis/lib/inc/sai_redis.h
    #sed -i 's/TimerWatchdog twd(30 \* 1000000);/TimerWatchdog twd(2147 * 1000000);/g' src/sonic-sairedis/syncd/syncd.cpp
    sed -i 's/#define SELECT_TIMEOUT 1000/#define SELECT_TIMEOUT 1999999/g' src/sonic-swss/orchagent/orchdaemon.cpp
    sed -i 's/(60\*1000)/(1999999)/g' src/sonic-sairedis/lib/src/RedisChannel.cpp

    #5 copp configuration for jumbo
    sed -i 's/"cir":"600",/"cir":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json
    sed -i 's/"cbs":"600",/"cbs":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json

    # Download hwsku
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_sonic_falcon_hwsku.tgz
    rm -fr device/marvell/x86_64-marvell_db98cx8580_32cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8580_32cd-r0  || true
    rm -fr device/marvell/x86_64-marvell_db98cx8540_16cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8540_16cd-r0  || true
    tar -C device/marvell/ -xzf mrvl_sonic_falcon_hwsku.tgz
    cp -dr device/marvell/arm64-marvell_db98cx8580_32cd-r0 device/marvell/x86_64-marvell_db98cx8580_32cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8540_16cd-r0 device/marvell/x86_64-marvell_db98cx8540_16cd-r0

    #6 Overwrite default profile with 32x25G 12.8T
    cp -rv device/marvell/x86_64-marvell_db98cx8580_32cd-r0/FALCON32X25G/* device/marvell/x86_64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/
    cp -rv device/marvell/arm64-marvell_db98cx8580_32cd-r0/FALCON32X25G/* device/marvell/arm64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/

    #7 Overwrite default profile with 16x25G 6.4T
    cp -rv device/marvell/x86_64-marvell_db98cx8540_16cd-r0/FALCON16X25G/* device/marvell/x86_64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/ || true
    cp -rv device/marvell/arm64-marvell_db98cx8540_16cd-r0/FALCON16X25G/* device/marvell/arm64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/ || true

    #7 ARM64 jessie target
    sed -i 's/apt-get update/apt-get -o Acquire::Check-Valid-Until=false update/'g sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get install -y/apt-get install --force-yes -y/'g sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get -y/apt-get --force-yes -y/'g sonic-slave-jessie/Dockerfile.j2

    #8 Add Falcon module  
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/falcon_modules.patch
    patch -p1 < falcon_modules.patch

    #9 TODO: Intel USB access
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_usb_install_slow.patch
    patch -p1 < sonic_usb_install_slow.patch

}


build_fixes()
{
    sed -i '/RUN apt-get install -y rsyslog/i \
            RUN apt-get install -y cmake \
            RUN apt-mark manual cmake' sonic-slave-stretch/Dockerfile.j2

    sed -i '/EXPOSE 22/i \
            RUN apt-get install -y gem2deb \
            RUN apt-mark manual gem2deb \
            RUN apt-get install -y dh-systemd \
            RUN apt-mark manual dh-systemd \
            RUN apt-get install -y equivs \
            RUN apt-mark manual equivs \
            RUN apt-get install -y javahelper \
            RUN apt-mark manual javahelper \
            RUN apt-get install -y pkg-php-tools \
            RUN apt-mark manual pkg-php-tools \
            RUN apt-get install -y python-stdeb \
            RUN apt-mark manual python-stdeb \
            RUN apt-get install -y libssl1.0-dev \
            RUN apt-mark manual libssl1.0-dev \
            RUN apt-get install -y python-click \
            RUN apt-mark manual python-click \
            RUN apt-get install -y dh-strip-nondeterminism \
            RUN apt-mark manual dh-strip-nondeterminism \
            RUN apt-get install -y debhelper \
            RUN apt-mark manual debhelper \
            RUN apt-get install -y dh-systemd \
            RUN apt-mark manual dh-systemd \
            RUN apt-get install -y kernel-wedge \
            RUN apt-mark manual kernel-wedge \
            RUN apt-get install -y dh-autoreconf \
            RUN apt-mark manual dh-autoreconf \
            RUN apt-get install -y dh-exec \
            RUN apt-mark manual dh-exec \
            RUN apt-get install -y libssl-dev \
            RUN apt-mark manual libssl-dev \
            RUN apt-get install -y dh-make \
            RUN apt-mark manual dh-make' sonic-slave-stretch/Dockerfile.j2

    sed -i 's/dpkg-buildpackage /dpkg-buildpackage -d /' src/isc-dhcp/Makefile

    #sed -i 's/SONIC_/#SONIC_/g' rules/smartmontools.mk
    sed -i 's/dpkg-buildpackage -us/dpkg-buildpackage -d -us/' src/smartmontools/Makefile
    #sed -i 's/dh_installsystemd//' src/smartmontools/smartmontools-6.6/debian/rules
    sed -i '/dpkg-buildpackage/i \
	sed -i "/dh_installsystemd/d" debian/rules' src/smartmontools/Makefile

    sed -i '/fakeroot/i \
ifeq ($(CONFIGURED_ARCH), amd64) \
	echo 11 > debian\/compat \
endif' src/hiredis/Makefile


    sed -i 's/dpkg-buildpackage /dpkg-buildpackage -d /' src/redis/Makefile
    sed -i '/export/i \
ifeq ($(CONFIGURED_ARCH), amd64) \
	echo 11 > debian\/compat \
endif' src/redis/Makefile

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_falcon_libteam_dec14.patch
    patch -p1 < sonic_falcon_libteam_dec14.patch
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
        log "Checkout Dec14 sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_MASTER_JUN30_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    #build_fixes

    build_kernel_buster
    
    misc_workarounds

    master_sonic_fix    

    build_arm64_falcon
}

main $@

