#!/bin/bash

CURR_DIR="$PWD"

if [[ "$CURR_DIR" != *"/ABP-"*"/sonic-buildimage"* ]]; then
    echo "  Could run only in official ABP-***/sonic-buildimage/"
    exit 1
fi

# Extract ABP-... part (like ABP-trixie-04-11-2025_10-02)
SONIC_SOURCE_DIR="$(basename "$(dirname "$CURR_DIR")")"

# Extract BRANCH as second field between first and second '-'
BRANCH="$(echo "$SONIC_SOURCE_DIR" | cut -d'-' -f2)"
case "$BRANCH" in
    master|202505|202511)
        l_DEBIAN=bookworm
        ;;
    trixie)
        l_DEBIAN=trixie
        ;;
    *)
        echo " no correct branch specified"
        exit 1
        ;;
esac

# Extract ARCH from Target-BIN name
BUILD_PLATFORM_ARCH=""
if [[ -f target/sonic-marvell-prestera-armhf.bin ]]; then
    TARGET=target/sonic-marvell-prestera-armhf.bin
    TARGET_FILE=sonic-marvell-prestera-armhf.bin
    BUILD_PLATFORM_ARCH="armhf"
elif [[ -f target/sonic-marvell-prestera-arm64.bin ]]; then
    TARGET=target/sonic-marvell-prestera-arm64.bin
    TARGET_FILE=sonic-marvell-prestera-arm64.bin
    BUILD_PLATFORM_ARCH="arm64"
elif [[ -f target/sonic-marvell-prestera.bin ]]; then
    TARGET=target/sonic-marvell-prestera.bin
    TARGET_FILE=sonic-marvell-prestera.bin
    BUILD_PLATFORM_ARCH="amd64"
else
    echo " no Target-BIN file found"
    exit 1
fi


ARTIFACTS_DIR=/sonic-artifacts
ARTIFACTS_LOG=/sonic-artifacts/arti.log
LOG_BASE="http://10.2.141.103:8080/s-artifacts"
LOG_PATH=${LOG_BASE}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}
#LOG_PATH=$BUILD_ARTIFACTS_DIR

PLATFORM_SHORT_NAME="mrvl"
TARG_SUFFIX="$1"

copy_build_artifacts()
{
    # Ensure that artifacts is a NFS mount, to avoid modifying permissions of local directories
    if ! grep -s " ${ARTIFACTS_DIR} " /proc/mounts | grep -q "nfs"; then
        echo "$ARTIFACTS_DIR is not an NFS mount. Copy to artifacts directory failed"
        return 1
    fi

    BUILD_ARTIFACTS_DIR=${ARTIFACTS_DIR}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}/
    echo "Copy artifacts to ${ARTIFACTS_DIR}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}/ ..."
    # $ARTIFACTS_DIR is a shared mount across different Linux users.
    # If any user creates a directory with read-only permissions all subsequent inner directory creation fails,
    # to avoid such issues, set permissions before any copy.
    # Caution: depending upon network the recursive -R for whole ARTIFACTS_DIR became blocking
    #if [ "$BUILD_PLATFORM" == "marvell-teralynx" ]; then
    #    sudo chmod -R 777 ${ARTIFACTS_DIR} 2>&-
    #fi
    sudo mkdir -p -m 777 $BUILD_ARTIFACTS_DIR  2>&-

    cp commit_log.txt $BUILD_ARTIFACTS_DIR
    cp build_args.txt $BUILD_ARTIFACTS_DIR
    if [ "$TARG_SUFFIX" = "" ]; then
        cp -a ${TARGET} $BUILD_ARTIFACTS_DIR
        echo "${LOG_PATH}/$TARGET_FILE" >> $ARTIFACTS_LOG
        if [ -f target/debs/${l_DEBIAN}/swss-dbg_1.0.0_*.deb ]; then
            cp -a target/debs/${l_DEBIAN}/swss-dbg_1.0.0_*.deb $BUILD_ARTIFACTS_DIR
        fi
        cp -a target/debs/${l_DEBIAN}/sonic-platform-*.deb $BUILD_ARTIFACTS_DIR
        if [ -f target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz ]; then
            cp -a target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz $BUILD_ARTIFACTS_DIR
        fi
    else
        cp -a ${TARGET} ${BUILD_ARTIFACTS_DIR}/${TARGET_FILE}-${TARG_SUFFIX}
        echo "${LOG_PATH}/${TARGET_FILE}-${TARG_SUFFIX}" >> $ARTIFACTS_LOG
    fi
    echo "                           copy artifacts done"
}

copy_build_artifacts

