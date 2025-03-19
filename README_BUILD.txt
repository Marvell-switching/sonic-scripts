-------------------------------------------------------------------------------------------
README_BUILD.txt

This README_BUILD.txt contains brief description of build-process
  Over Marvell scripts   vs   Classic build

In a brief, this https://github.com/Marvell-switching/sonic-scripts.git contains
- TWO Main scripts - <sonic_build_script.sh> and <marvell_sonic_patch_script.sh>
- All patches currently out-of-sonic-buildimage-GIT
- <series_marvell-prestera_arm64> list of patches to be applied as <git am patch>
  The list is per-branch and per-architecture (amd64, arm64, armhf)
- HW device description/configuration/json file <prestera_hwsku.tgz>
  to override existing or add Marvell HW platform devices

Main script's steps are present in an auto-created file <sonic-buildimage/build_cmd.txt>

For details refer the 
    https://ewiki.marvell.com/display/SONiCDCTeam/SONiC+Build#SONiCBuild-Buildusingbuildscript

GITHUB links for clone:
    https://github.com/sonic-net/sonic-buildimage.git
    https://github.com/Marvell-switching/sonic-scripts.git
-------------------------------------------------------------------------------------------
BUILD-SERVER requirements:
    - 300G free disk-space
    - ARM machine       for arm64 and/or armhf architecture
    - X86/AMD64 machine for amd64 architecture
-------------------------------------------------------------------------------------------

file<<sonic_build_script.sh>>                               <<Classic build for Clean-SONiC>>
  ---------------------                                       -----------------------------

** Clear previously built objects
  docker system prune -a --volumes -f

** Clone SONiC branch and change-dir to sonic-buildimage           Clone SONiC
                                                                      |
** file<<marvell_sonic_patch_script.sh>>                              |
    **   patching sonic-buildimage                                    |
    **   make init                                                  make init
    **   git submodule update --init --recursive                      |
    **   patching submodules                                          |
           |                                                          |
           |                                                          |
 +------->>|                                                          |
 |         |                                                          |
 |    **** make configure PLATFORM=marvell-prestera PLATFORM_ARCH=arm64 ****
 |    ****      make  target/sonic-marvell-prestera-arm64.bin           ****
 |
 |    ** on failure or a change
 |         |
 <---------+

** OK/ERROR printed by script                              Manual check result by "echo $?"

===========================================================================================
    Some important intermediate target-build control-points

    systemd-sonic-generator_1.0.0_arm64.deb
    mrvlprestera_1.0_arm64.deb
    linux-headers-6.1.0-22-2-common_6.1.94-1_all.deb
    sonic-platform-nokia-7215-a1_1.0_arm64.deb
    sonic-platform-rd98dx35xx_1.0_arm64.deb
    initramfs-tools_0.142_all.deb
    sonic-device-data_1.0-1_all.deb
    systemd-sonic-generator_1.0.0_arm64.deb.log
    mrvlprestera_1.0_arm64.deb.log
    linux-headers-6.1.0-22-2-arm64_6.1.94-1_arm64.deb
    sonic-platform-nokia-7215-a1_1.0_arm64.deb.log
    sonic-platform-rd98dx35xx_1.0_arm64.deb.log
    sonic-platform-rd98dx35xx-cn9131_1.0_arm64.deb
    linux-image-6.1.0-22-2-arm64-unsigned_6.1.94-1_arm64.deb
    sonic-device-data_1.0-1_all.deb
    libnl-***
    openssh-server_9.2p1-2+deb12u5_arm64.deb
    python3-swsscommon_1.0.0_arm64.deb
    libswsscommon-dev_1.0.0_arm64.deb
    sonic-eventd_1.0.0-0_arm64.deb
    openssl_3.0.11-1~deb12u2+fips_arm64.deb
    libssl-dev_3.0.11-1~deb12u2+fips_arm64.deb
    openssh-client_9.2p1-2+deb12u5+fips_arm64.deb
    openssh-server_9.2p1-2+deb12u5+fips_arm64.deb
    libsairedis_1.0.0_arm64.deb
    mrvllibsai_1.15.1-1_arm64.deb
    syncd_1.0.0_arm64.deb.dep
    sonic_config_engine-1.0-py3-none-any.whl
--FINAL:
    sonic-marvell-prestera-arm64.bin
