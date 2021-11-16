#!/bin/bash

fw_uboot_env_cfg()
{
    echo "Setting up U-Boot environment..."
    MACH_FILE="/host/machine.conf"
    PLATFORM=`sed -n 's/onie_platform=\(.*\)/\1/p' $MACH_FILE`

    if [ "$PLATFORM" = "arm64-marvell_rd98DX7312_32G16HVG6HLG-r0" ]; then
        FW_ENV_DEFAULT='/dev/mtd0 0x400000 0x10000 0x10000'
    else
        FW_ENV_DEFAULT='/dev/mtd1 0x0 0x10000 0x100000'
    fi

    echo $FW_ENV_DEFAULT > /etc/fw_env.config
}

main()
{
    fw_uboot_env_cfg
}

main $@
