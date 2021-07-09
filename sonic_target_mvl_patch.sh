# Description: Applying open PRs needed for ARM arch compilation


#
# patch script for ARM64 Falcon board
#

#
# CONFIGURATIONS:-
#

SONIC_MASTER_JUN30_COMMIT="99b03cff4571fcb6983e902ad2bbfbaaf0f442df"

declare -a PATCHES=(P8 P9 P10)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"


declare -A P8=( [NAME]=sonic-buildimage [DIR]=. [PR]="14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 37 38 39 40 41 42 43 44 " \
[URL]="https://github.com/Marvell-OpenNOS" [PREREQ]="" [POSTREQ]="")
declare -A P9=( [NAME]=sonic-platform-common [DIR]=src/sonic-platform-common [PR]="1" [URL]="https://github.com/Marvell-OpenNOS" [PREREQ]="" [POSTREQ]="")
declare -A P10=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]=" 6 " [URL]="https://github.com/Marvell-OpenNOS" [PREREQ]="" [POSTREQ]="")

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




#master_sonic_fix()
#{

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

#changes are present 
    # netlink rxBuf Size to 3M patch
#    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/netlink_rxBufSize.patch
#    patch -p1 --dry-run < ./netlink_rxBufSize.patch
#    patch -p1 < ./netlink_rxBufSize.patch

#commnted its not present in master
#    # wheel
#    sed -i '/keep pip installed/i \
#sudo https_proxy=$https_proxy LANG=C chroot $FILESYSTEM_ROOT pip install wheel' build_debian.sh



#file not present 

    # Mac address fix
#    sed -i  "s/'cat'/'cat '/g" src/sonic-config-engine/sonic_device_util.py
# scripts/generate_dump is not present 
#    # sonic_generate_dump patch
#    pushd src/sonic-utilities
#    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_generate_dump.patch
#    patch -p1 --dry-run < ./sonic_generate_dump.patch
#    patch -p1 < ./sonic_generate_dump.patch

#    # cli performance improvement patch
#    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/cli_perf_improvement.patch
#    patch -p1 --dry-run < ./cli_perf_improvement.patch
#    patch -p1 < ./cli_perf_improvement.patch
#    popd
   
    #disable management frmwork
# config is value is not present in the file 
#    sed -i 's/ENABLE_MGMT_FRAMEWORK = y/ENABLE_MGMT_FRAMEWORK = N/g' rules/config
#}



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

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master/radius_arm64_build.patch
    patch -p1 --dry-run < ./radius_arm64_build.patch
    patch -p1 < ./radius_arm64_build.patch

    #redis workaround to increase lua-time-limit to 20000ms
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/redis_wa.patch
    patch -p1 < redis_wa.patch

    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-py-common/sonic_py_common/device_info.py

    # snmp subagent
    #echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2

    #1 Disable Mgmt Framework and Telemetry
    sed -i 's/INCLUDE_MGMT_FRAMEWORK = y/INCLUDE_MGMT_FRAMEWORK = n/g' rules/config
    sed -i 's/INCLUDE_SYSTEM_TELEMETRY = y/INCLUDE_SYSTEM_TELEMETRY = n/g' rules/config

    #2 TODO: Add Entropy workaround for ARM64
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
        sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
        python /etc/ent.py &' files/image_config/platform/rc.local


    #4 Watchdog/select Timeout  workaround
    sed -i 's/#define SELECT_TIMEOUT 1000/#define SELECT_TIMEOUT 1999999/g' src/sonic-swss/orchagent/orchdaemon.cpp
    sed -i 's/(60\*1000)/(1999999)/g' src/sonic-sairedis/lib/inc/sairedis.h

    #5 copp configuration for jumbo
    sed -i 's/"cir":"600",/"cir":"6000",/g' files/image_config/copp/copp_cfg.j2
    sed -i 's/"cbs":"600",/"cbs":"6000",/g' files/image_config/copp/copp_cfg.j2
    #6 TARGET specific changes 
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm64_TG48MP_DTS_and_Kernel_config.patch

    patch -p1 --dry-run < ./arm64_TG48MP_DTS_and_Kernel_config.patch
    echo "Patching tg48mp kernel changes"
    patch -p1 < ./arm64_TG48MP_DTS_and_Kernel_config.patch
    
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/arm64_TG4810M_DTS_and_Kernel_config.patch

    patch -p1 --dry-run < ./arm64_TG4810M_DTS_and_Kernel_config.patch
    echo "Patching tg4810m kernel changes"
    patch -p1 < ./arm64_TG4810M_DTS_and_Kernel_config.patch


    #9 TODO: Intel USB access
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_usb_install_slow.patch
    patch -p1 < sonic_usb_install_slow.patch

    # Update SAI 1.6.3
    sed -i 's/1.8.1-1/1.7.1-1/g' platform/marvell-arm64/sai.mk

}



misc_workarounds()
{

#check for correspnding arm64
    #8 Add Falcon module  
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/falcon_modules.patch
    patch -p1 < falcon_modules.patch

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


    enable_sdk_shell

    bug_fixes
    
    misc_workarounds


}

main $@

